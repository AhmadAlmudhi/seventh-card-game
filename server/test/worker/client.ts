/** Test helpers for the Worker and Room: an HTTP/WebSocket test client and time travel for saved rooms. */
import { env, runDurableObjectAlarm, runInDurableObject, SELF } from 'cloudflare:test';
import type { PublicView } from '../../src/engine/engine';
import type { ServerErrorCode, ServerMessage } from '../../src/protocol';
import type { Room, StoredRoom } from '../../src/room';

export const SITE = 'https://ahmadalmudhi.github.io';
const BASE = 'https://server.test';

export async function createRoom(origin: string | null = SITE): Promise<string> {
	const response = await SELF.fetch(`${BASE}/api/rooms`, { method: 'POST', headers: origin ? { Origin: origin } : {} });
	if (response.status !== 201) throw new Error(`room creation failed: ${response.status}`);
	return ((await response.json()) as { code: string }).code;
}

type Update = Extract<ServerMessage, { type: 'update' }>;
type Waiter = { predicate: (m: ServerMessage | string) => boolean; resolve: (m: ServerMessage | string) => void };

let deviceCounter = 0;

/** One player's connection to a room. */
export class Client {
	/** Every message received, in order. Non-JSON messages (the keepalive `pong`) are kept as strings. */
	readonly received: Array<ServerMessage | string> = [];
	closed?: { code: number; reason: string };
	playerId?: string;
	token?: string;
	readonly deviceId: string;
	private cursor = 0;
	private waiters: Waiter[] = [];

	private constructor(
		private readonly ws: WebSocket,
		deviceId?: string,
	) {
		this.deviceId = deviceId ?? `test-device-${String(++deviceCounter).padStart(6, '0')}`;
		ws.addEventListener('message', (event) => {
			const data = event.data as string;
			let message: ServerMessage | string = data;
			try {
				message = JSON.parse(data) as ServerMessage;
			} catch {
				// keep as a string
			}
			this.received.push(message);
			this.flush();
		});
		ws.addEventListener('close', (event) => {
			this.closed = { code: event.code, reason: event.reason };
			this.flush();
		});
	}

	static async connect(code: string, opts: { origin?: string | null; deviceId?: string } = {}): Promise<Client> {
		const origin = opts.origin === undefined ? SITE : opts.origin;
		const headers: Record<string, string> = { Upgrade: 'websocket' };
		if (origin) headers.Origin = origin;
		const response = await SELF.fetch(`${BASE}/parties/room/${code}`, { headers });
		if (!response.webSocket) throw new Error(`upgrade refused: ${response.status}`);
		response.webSocket.accept();
		return new Client(response.webSocket, opts.deviceId);
	}

	/** Connects and joins (or reconnects with `token`). Resolves with the welcome, or throws with the error code. */
	static async join(code: string, nickname: string, opts: { token?: string; deviceId?: string } = {}): Promise<Client> {
		const client = await Client.connect(code, { deviceId: opts.deviceId });
		const error = await client.hello(nickname, opts.token);
		if (error) throw new Error(`join refused: ${error}`);
		return client;
	}

	/** Sends hello. Returns undefined on welcome, or the error code. */
	async hello(nickname: string, token?: string): Promise<ServerErrorCode | undefined> {
		this.send({ type: 'hello', nickname, deviceId: this.deviceId, ...(token ? { token } : {}) });
		const reply = await this.waitFor((m) => typeof m !== 'string' && (m.type === 'welcome' || m.type === 'error'));
		if (typeof reply === 'string' || reply.type === 'update') throw new Error('unexpected reply');
		if (reply.type === 'error') return reply.code;
		this.playerId = reply.playerId;
		this.token = reply.token;
		return undefined;
	}

	send(message: unknown): void {
		this.ws.send(typeof message === 'string' ? message : JSON.stringify(message));
	}

	private sentAt: number[] = [];

	/** Sends like a person would: stays under the server's limit of 10 messages per second (PRD §8.5). */
	async paced(message: unknown): Promise<void> {
		for (;;) {
			const now = Date.now();
			this.sentAt = this.sentAt.filter((t) => now - t < 1000);
			if (this.sentAt.length < 9) break;
			await new Promise((resolve) => setTimeout(resolve, 1000 - (now - this.sentAt[0]!) + 5));
		}
		this.sentAt.push(Date.now());
		this.send(message);
	}

	close(): void {
		this.ws.close(1000, 'bye');
	}

	/** Resolves with the next message (after the ones already consumed) matching `predicate`. */
	waitFor(predicate: (m: ServerMessage | string) => boolean, timeoutMs = 10_000): Promise<ServerMessage | string> {
		const found = this.take(predicate);
		if (found !== undefined) return Promise.resolve(found);
		return new Promise((resolve, reject) => {
			const timer = setTimeout(() => {
				this.waiters = this.waiters.filter((w) => w !== waiter);
				const errors = this.received.filter((m) => typeof m !== 'string' && m.type === 'error');
				const last = JSON.stringify(this.received.at(-1))?.slice(0, 300);
				reject(new Error(`timed out waiting for a message; errors so far: ${JSON.stringify(errors)}; last received: ${last}`));
			}, timeoutMs);
			const waiter: Waiter = {
				predicate,
				resolve: (m) => {
					clearTimeout(timer);
					resolve(m);
				},
			};
			this.waiters.push(waiter);
		});
	}

	async nextUpdate(predicate: (u: Update) => boolean = () => true): Promise<Update> {
		return (await this.waitFor((m) => typeof m !== 'string' && m.type === 'update' && predicate(m))) as Update;
	}

	async nextError(): Promise<ServerErrorCode> {
		const message = await this.waitFor((m) => typeof m !== 'string' && m.type === 'error');
		return (message as Extract<ServerMessage, { type: 'error' }>).code;
	}

	/** Waits until the socket is closed by the server. */
	async waitClosed(timeoutMs = 10_000): Promise<{ code: number; reason: string }> {
		const started = Date.now();
		while (!this.closed) {
			if (Date.now() - started > timeoutMs) throw new Error('socket was not closed');
			await new Promise((r) => setTimeout(r, 10));
		}
		return this.closed;
	}

	get lastVersion(): number {
		for (let i = this.received.length - 1; i >= 0; i--) {
			const m = this.received[i]!;
			if (typeof m !== 'string' && m.type === 'update') return m.version;
		}
		return 0;
	}

	/** Skips past everything received so far and returns the latest view. */
	drain(): PublicView {
		this.cursor = this.received.length;
		return this.view;
	}

	/** The most recent view received, without consuming anything. */
	get view(): PublicView {
		for (let i = this.received.length - 1; i >= 0; i--) {
			const m = this.received[i]!;
			if (typeof m !== 'string' && m.type === 'update') return m.view;
		}
		throw new Error('no update received yet');
	}

	private take(predicate: (m: ServerMessage | string) => boolean): ServerMessage | string | undefined {
		for (let i = this.cursor; i < this.received.length; i++) {
			if (predicate(this.received[i]!)) {
				this.cursor = i + 1;
				return this.received[i];
			}
		}
		return undefined;
	}

	private flush(): void {
		for (const waiter of [...this.waiters]) {
			const found = this.take(waiter.predicate);
			if (found !== undefined) {
				this.waiters = this.waiters.filter((w) => w !== waiter);
				waiter.resolve(found);
			}
		}
	}
}

export function roomStub(code: string): DurableObjectStub<Room> {
	return env.Room.get(env.Room.idFromName(code));
}

/** Reads a room's saved state directly from storage. */
export async function stored(code: string): Promise<StoredRoom | undefined> {
	return runInDurableObject(roomStub(code), async (_instance: Room, state) => state.storage.get<StoredRoom>('room'));
}

/**
 * Edits a room's saved state (for example, moving a deadline into the past), drops the room's
 * in-memory copy so it reloads from storage, then fires its alarm, like time passing.
 */
export async function timeTravel(code: string, edit: (room: StoredRoom, now: number) => void): Promise<boolean> {
	const stub = roomStub(code);
	await runInDurableObject(stub, async (instance: Room, state) => {
		const room = (await state.storage.get<StoredRoom>('room'))!;
		edit(room, Date.now());
		await state.storage.put('room', room);
		(instance as unknown as { room: unknown }).room = undefined;
	});
	return runDurableObjectAlarm(stub);
}

/** Waits for a moment so in-flight messages are delivered. */
export function settle(ms = 30): Promise<void> {
	return new Promise((resolve) => setTimeout(resolve, ms));
}
