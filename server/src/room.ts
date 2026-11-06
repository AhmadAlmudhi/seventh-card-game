/**
 * The Room Durable Object: one per room code (PRD §8.3).
 *
 * It only translates. Messages, closed sockets and alarms become engine actions; the engine's new
 * state is saved before anyone hears about it; then the same update goes to every player.
 */
import { Server, type Connection, type WSMessage } from 'partyserver';
import {
	applyAction,
	createRoom,
	dueActions,
	nextDeadline,
	publicView,
	type Action,
	type ApplyResult,
	type GameEvent,
	type GameState,
	type RoomOptions,
} from './engine/engine';
import { cryptoRng } from './engine/rng';
import {
	ClientMessage,
	CloseCode,
	MAX_MESSAGE_BYTES,
	MAX_MESSAGES_PER_SECOND,
	MAX_RATE_STRIKES,
	type ServerErrorCode,
	type ServerMessage,
} from './protocol';

/** A room with nobody connected (outside a pause) is deleted after this long (PRD R-6). */
export const EMPTY_ROOM_TTL_MS = 10 * 60_000;
/** An abandoned game's room is deleted after this long, so connected players see what happened first. */
export const ABANDONED_ROOM_TTL_MS = 60_000;
/** Alarms never fire more often than this, even if something keeps reporting a past deadline. */
const MIN_ALARM_GAP_MS = 250;

/** Saved under one storage key after every change (PRD §8.3, C-5). */
export interface StoredRoom {
	state: GameState;
	/** When the room last became empty of connected players, outside a pause. Drives cleanup. */
	emptySince?: number;
	/** When the game was abandoned (Rules §12.5). */
	abandonedAt?: number;
}

/** Kept on each socket, so it survives hibernation. */
interface ConnectionState {
	playerId?: string;
	/** Rate limiting: the current one-second window. */
	windowStart: number;
	count: number;
	strikes: number;
}

type Conn = Connection<ConnectionState>;
type Hello = Extract<ClientMessage, { type: 'hello' }>;
type Result = ApplyResult | { ok: false; error: ServerErrorCode };

const rng = cryptoRng();

export class Room extends Server<Env> {
	static options = { hibernate: true };

	/** Cached saved room: `undefined` until loaded, `null` if no room has this code. */
	private room: StoredRoom | null | undefined;

	onStart(): void {
		// Keepalive pings are answered without waking the room (PRD §8.5).
		this.ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair('ping', 'pong'));
	}

	/** Called by the Worker to create the room. Returns false if a room with this code already exists. */
	async init(opts: RoomOptions = {}): Promise<boolean> {
		if (await this.load()) return false;
		await this.save({ state: createRoom(opts) }, []);
		return true;
	}

	onConnect(conn: Conn): void {
		conn.setState({ windowStart: Date.now(), count: 0, strikes: 0 });
	}

	async onMessage(conn: Conn, raw: WSMessage): Promise<void> {
		if (!this.withinRateLimit(conn)) return;
		const message = parse(raw);
		if (!message) return this.sendError(conn, 'INVALID_MESSAGE');

		const room = await this.load();
		if (!room) return this.refuse(conn, 'ROOM_NOT_FOUND', CloseCode.ROOM_CLOSED);
		if (message.type === 'hello') return this.hello(conn, room, message);

		const playerId = conn.state?.playerId;
		if (!playerId) return this.sendError(conn, 'NOT_JOINED');

		const result = this.apply(room.state, toAction(message, playerId));
		if (!result.ok) return this.sendError(conn, result.error);
		await this.save({ ...room, state: result.state }, result.events);

		if (message.type === 'remove') {
			for (const other of this.connectionsOf(message.playerId)) this.refuse(other, 'REMOVED', CloseCode.REFUSED);
		}
		if (message.type === 'quit') {
			this.detach(conn);
			conn.close(CloseCode.QUIT, 'quit');
		}
	}

	async onClose(conn: Conn): Promise<void> {
		const playerId = conn.state?.playerId;
		if (!playerId) return;
		// A newer connection for the same player replaced this one: they never left.
		if (this.connectionsOf(playerId).some((other) => other.id !== conn.id)) return;
		const room = await this.load();
		if (!room) return;
		const result = this.apply(room.state, { type: 'disconnect', playerId });
		if (result.ok && result.events.length > 0) await this.save({ ...room, state: result.state }, result.events);
	}

	async onAlarm(): Promise<void> {
		const room = await this.load();
		if (!room) return;
		const now = Date.now();
		if (isExpired(room, now)) return this.destroy();

		// Run everything that's due, in time order (PRD §8.3).
		let state = room.state;
		const events: GameEvent[] = [];
		for (let i = 0; i < 100; i++) {
			const due = dueActions(state, now)[0];
			if (!due) break;
			const result = this.apply(state, due.action, now);
			if (!result.ok) {
				console.error('scheduled action refused', due.action, result.error);
				break;
			}
			state = result.state;
			events.push(...result.events);
		}
		if (events.length > 0) await this.save({ ...room, state }, events);
		else await this.schedule(room);
	}

	// -------------------------------------------------------------------------
	// Joining and reconnecting
	// -------------------------------------------------------------------------

	/** First message on every connection. Without a token: join. With a known token: reconnect (PRD §8.5). */
	private async hello(conn: Conn, room: StoredRoom, hello: Hello): Promise<void> {
		if (conn.state?.playerId) return this.sendError(conn, 'NOT_ALLOWED');
		const state = room.state;
		const existing = hello.token ? state.players.find((p) => !p.bot && p.token === hello.token) : undefined;

		if (existing) {
			if (existing.status === 'left') return this.refuse(conn, 'SEAT_LOST', CloseCode.REFUSED);
			const result = this.apply(state, { type: 'reconnect', playerId: existing.id });
			if (!result.ok) return this.refuse(conn, result.error, CloseCode.REFUSED);
			this.attach(conn, existing.id);
			for (const other of this.connectionsOf(existing.id)) {
				if (other.id !== conn.id) {
					this.detach(other);
					other.close(CloseCode.REPLACED, 'replaced');
				}
			}
			this.send(conn, { type: 'welcome', playerId: existing.id, token: existing.token, roomCode: this.name });
			if (result.events.length > 0) await this.save({ ...room, state: result.state }, result.events);
			else this.send(conn, updateMessage(state, []));
			return;
		}

		const playerId = newPlayerId(state);
		const token = randomHex(16);
		const result = this.apply(state, { type: 'join', playerId, token, deviceId: hello.deviceId, nickname: hello.nickname });
		if (!result.ok) return this.refuse(conn, result.error, CloseCode.REFUSED);
		this.attach(conn, playerId);
		this.send(conn, { type: 'welcome', playerId, token, roomCode: this.name });
		await this.save({ ...room, state: result.state }, result.events);
	}

	// -------------------------------------------------------------------------
	// State, storage and the alarm
	// -------------------------------------------------------------------------

	/** Every handler starts here: after hibernation, memory is empty (PRD §8.3). */
	private async load(): Promise<StoredRoom | null> {
		if (this.room === undefined) this.room = (await this.ctx.storage.get<StoredRoom>('room')) ?? null;
		return this.room;
	}

	private apply(state: GameState, action: Action, now = Date.now()): Result {
		try {
			return applyAction(state, action, { rng, now });
		} catch (error) {
			console.error('engine error', action, error);
			return { ok: false, error: 'INTERNAL' };
		}
	}

	/** Saves first, then schedules the alarm, then tells every player (PRD §8.3). */
	private async save(next: StoredRoom, events: GameEvent[]): Promise<void> {
		const now = Date.now();
		const previous = this.room ?? undefined;
		const state = next.state;
		state.version = (previous?.state.version ?? 0) + 1;

		// The tutorial's bot is always "connected", so it doesn't count: a room only it is in gets cleaned up.
		const anyoneConnected = state.players.some((p) => p.connected && !p.bot && p.status !== 'left');
		const stored: StoredRoom = {
			state,
			emptySince: anyoneConnected || state.phase === 'paused' ? undefined : (previous?.emptySince ?? now),
			abandonedAt: state.phase === 'abandoned' ? (previous?.abandonedAt ?? now) : undefined,
		};
		await this.ctx.storage.put('room', stored);
		this.room = stored;
		await this.schedule(stored);
		if (events.length > 0) this.broadcastUpdate(state, events);
	}

	/** A Durable Object has one alarm, so it's set to the earliest of every deadline. */
	private async schedule(room: StoredRoom): Promise<void> {
		const times = [
			nextDeadline(room.state),
			room.emptySince !== undefined ? room.emptySince + EMPTY_ROOM_TTL_MS : undefined,
			room.abandonedAt !== undefined ? room.abandonedAt + ABANDONED_ROOM_TTL_MS : undefined,
		].filter((t): t is number => t !== undefined);
		if (times.length === 0) {
			await this.ctx.storage.deleteAlarm();
			return;
		}
		await this.ctx.storage.setAlarm(Math.max(Math.min(...times), Date.now() + MIN_ALARM_GAP_MS));
	}

	/** Closes every socket and deletes everything this room saved. */
	private async destroy(): Promise<void> {
		for (const conn of this.getConnections<ConnectionState>()) this.refuse(conn, 'ROOM_NOT_FOUND', CloseCode.ROOM_CLOSED);
		await this.ctx.storage.deleteAlarm();
		await this.ctx.storage.deleteAll();
		this.room = null;
	}

	// -------------------------------------------------------------------------
	// Connections
	// -------------------------------------------------------------------------

	private connectionsOf(playerId: string): Conn[] {
		return [...this.getConnections<ConnectionState>()].filter((c) => c.state?.playerId === playerId);
	}

	private attach(conn: Conn, playerId: string): void {
		conn.setState((prev) => ({ windowStart: Date.now(), count: 0, strikes: 0, ...prev, playerId }));
	}

	/** Unlinks a socket from its player, so closing it doesn't count as a disconnect. */
	private detach(conn: Conn): void {
		conn.setState((prev) => ({ windowStart: Date.now(), count: 0, strikes: 0, ...prev, playerId: undefined }));
	}

	private broadcastUpdate(state: GameState, events: GameEvent[]): void {
		const message = JSON.stringify(updateMessage(state, events));
		for (const conn of this.getConnections<ConnectionState>()) {
			if (conn.state?.playerId) trySend(conn, message);
		}
	}

	private send(conn: Conn, message: ServerMessage): void {
		trySend(conn, JSON.stringify(message));
	}

	private sendError(conn: Conn, code: ServerErrorCode): void {
		this.send(conn, { type: 'error', code });
	}

	/** Sends the error, then closes the socket: the app shows the message and doesn't retry. */
	private refuse(conn: Conn, code: ServerErrorCode, closeCode: number): void {
		this.sendError(conn, code);
		this.detach(conn);
		conn.close(closeCode, code);
	}

	/** At most MAX_MESSAGES_PER_SECOND per connection; repeated abuse closes it (PRD §8.5). */
	private withinRateLimit(conn: Conn): boolean {
		const now = Date.now();
		const prev = conn.state ?? { windowStart: now, count: 0, strikes: 0 };
		const fresh = now - prev.windowStart >= 1000;
		const next = {
			...prev,
			windowStart: fresh ? now : prev.windowStart,
			count: (fresh ? 0 : prev.count) + 1,
			strikes: prev.strikes,
		};
		const limit = Number(this.env.RATE_LIMIT_PER_SECOND) || MAX_MESSAGES_PER_SECOND;
		const allowed = next.count <= limit;
		if (!allowed) next.strikes += 1;
		conn.setState(next);
		if (!allowed && next.strikes > MAX_RATE_STRIKES) this.refuse(conn, 'RATE_LIMITED', CloseCode.RATE_LIMITED);
		return allowed;
	}
}

function parse(raw: WSMessage): ClientMessage | null {
	if (typeof raw !== 'string' || new TextEncoder().encode(raw).length > MAX_MESSAGE_BYTES) return null;
	try {
		const parsed = ClientMessage.safeParse(JSON.parse(raw));
		return parsed.success ? parsed.data : null;
	} catch {
		return null;
	}
}

function toAction(message: Exclude<ClientMessage, Hello>, by: string): Action {
	switch (message.type) {
		case 'settings':
			return { type: 'settings', by, mode: message.mode, targetScore: message.targetScore };
		case 'start':
			return { type: 'start', by };
		case 'hit':
			return { type: 'hit', by, decisionId: message.decisionId };
		case 'stay':
			return { type: 'stay', by, decisionId: message.decisionId };
		case 'choose':
			return { type: 'choose', by, decisionId: message.decisionId, targetId: message.targetId };
		case 'continue':
			return { type: 'continue', by };
		case 'remove':
			return { type: 'remove', by, playerId: message.playerId };
		case 'quit':
			return { type: 'quit', by };
	}
}

function updateMessage(state: GameState, events: GameEvent[]): ServerMessage {
	return { type: 'update', version: state.version, now: Date.now(), events, view: publicView(state) };
}

function isExpired(room: StoredRoom, now: number): boolean {
	if (room.emptySince !== undefined && now >= room.emptySince + EMPTY_ROOM_TTL_MS) return true;
	return room.abandonedAt !== undefined && now >= room.abandonedAt + ABANDONED_ROOM_TTL_MS;
}

function trySend(conn: Conn, message: string): void {
	try {
		conn.send(message);
	} catch {
		// The socket is already closing; its onClose will handle the disconnect.
	}
}

/** Public player id: short, random and unique within the room. */
function newPlayerId(state: GameState): string {
	for (;;) {
		const id = randomHex(4);
		if (!state.players.some((p) => p.id === id)) return id;
	}
}

/** A random hex string from crypto randomness. 16 bytes = the 128-bit token (PRD §8.5). */
function randomHex(bytes: number): string {
	const buffer = crypto.getRandomValues(new Uint8Array(bytes));
	return [...buffer].map((b) => b.toString(16).padStart(2, '0')).join('');
}
