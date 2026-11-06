import { evictDurableObject, SELF } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import { GRACE_MS, PAUSE_MS } from '../../src/engine/constants';
import type { PublicView } from '../../src/engine/engine';
import { CloseCode } from '../../src/protocol';
import { EMPTY_ROOM_TTL_MS } from '../../src/room';
import { Client, createRoom, roomStub, settle, SITE, stored, timeTravel } from './client';

const BASE = 'https://server.test';

describe('creating rooms (PRD §8.2)', () => {
	it('returns a 5-character code with no look-alike characters, with CORS for the web app', async () => {
		const response = await SELF.fetch(`${BASE}/api/rooms`, { method: 'POST', headers: { Origin: SITE } });
		expect(response.status).toBe(201);
		expect(response.headers.get('Access-Control-Allow-Origin')).toBe(SITE);
		const { code } = (await response.json()) as { code: string };
		expect(code).toMatch(/^[ABCDEFGHJKMNPQRSTUVWXYZ2-9]{5}$/);
	});

	it('answers the CORS preflight', async () => {
		const response = await SELF.fetch(`${BASE}/api/rooms`, { method: 'OPTIONS', headers: { Origin: SITE } });
		expect(response.status).toBe(204);
		expect(response.headers.get('Access-Control-Allow-Methods')).toContain('POST');
	});

	it('allows the mobile apps, which send no Origin, and localhost', async () => {
		await createRoom(null);
		await createRoom('http://localhost:8080');
	});

	it('refuses other websites, for creating and for connecting (PRD §8.7)', async () => {
		const response = await SELF.fetch(`${BASE}/api/rooms`, { method: 'POST', headers: { Origin: 'https://evil.example' } });
		expect(response.status).toBe(403);
		const code = await createRoom();
		const upgrade = await SELF.fetch(`${BASE}/parties/room/${code}`, { headers: { Upgrade: 'websocket', Origin: 'https://evil.example' } });
		expect(upgrade.status).toBe(403);
	});

	it('rejects malformed room codes before opening a connection', async () => {
		for (const code of ['abcde', 'AB1DE', 'ABCD', 'ABCDEF']) {
			const response = await SELF.fetch(`${BASE}/parties/room/${code}`, { headers: { Upgrade: 'websocket', Origin: SITE } });
			expect(response.status).toBe(404);
		}
	});
});

describe('joining (PRD §4.3)', () => {
	it('refuses a code nobody created with ROOM_NOT_FOUND', async () => {
		const client = await Client.connect('ZZZZZ');
		expect(await client.hello('Ali')).toBe('ROOM_NOT_FOUND');
		expect((await client.waitClosed()).code).toBe(CloseCode.ROOM_CLOSED);
	});

	it('welcomes the player, makes the first one host, and sends everyone the room', async () => {
		const code = await createRoom();
		const ali = await Client.join(code, 'Ali');
		expect(ali.token).toMatch(/^[0-9a-f]{32}$/);
		const sara = await Client.join(code, 'Sara');
		const update = await ali.nextUpdate((u) => u.view.players.length === 2);
		expect(update.view.hostId).toBe(ali.playerId);
		expect(update.view.players.map((p) => p.nickname)).toEqual(['Ali', 'Sara']);
		expect(JSON.stringify(update)).not.toContain(sara.token!);
	});

	it('refuses taken and invalid nicknames, and a 9th player', async () => {
		const code = await createRoom();
		await Client.join(code, 'Ali');
		const dup = await Client.connect(code);
		expect(await dup.hello('ali')).toBe('NICKNAME_TAKEN');
		expect((await dup.waitClosed()).code).toBe(CloseCode.REFUSED);
		const bad = await Client.connect(code);
		expect(await bad.hello('x'.repeat(17))).toBe('INVALID_NICKNAME');
		for (let i = 2; i <= 8; i++) await Client.join(code, `Player ${i}`);
		const ninth = await Client.connect(code);
		expect(await ninth.hello('Ninth')).toBe('ROOM_FULL');
	});

	it('refuses game messages before hello, broken JSON and unknown types', async () => {
		const code = await createRoom();
		const client = await Client.connect(code);
		client.send({ type: 'start' });
		expect(await client.nextError()).toBe('NOT_JOINED');
		client.send('{not json');
		expect(await client.nextError()).toBe('INVALID_MESSAGE');
		client.send({ type: 'cheat', amount: 1000 });
		expect(await client.nextError()).toBe('INVALID_MESSAGE');
		client.send({ type: 'hello', nickname: 'x'.repeat(3000), deviceId: client.deviceId });
		expect(await client.nextError()).toBe('INVALID_MESSAGE');
	});

	it('answers keepalive pings with pong', async () => {
		const code = await createRoom();
		const client = await Client.connect(code);
		client.send('ping');
		expect(await client.waitFor((m) => m === 'pong')).toBe('pong');
	});
});

/** Answers every decision until the game ends, moving the clock past each break between rounds. */
async function playToEnd(code: string, players: Client[]): Promise<PublicView> {
	const observer = players[0]!;
	const answered = new Set<string>();
	const log: string[] = [];
	let view = observer.drain();
	for (let step = 0; step < 3000; step++) {
		if (view.phase === 'results') return view;
		log.push(
			`v${observer.lastVersion} ${view.phase} ${view.decision?.id ?? '-'}:${view.decision?.kind ?? ''}:${view.decision?.playerId ?? ''}`,
		);
		if (view.phase === 'round_over') {
			await timeTravel(code, (room, now) => {
				room.state.nextRoundAt = now - 1;
			});
		} else if (view.decision && !answered.has(view.decision.id)) {
			const decision = view.decision;
			answered.add(decision.id);
			log.push(`  answer ${decision.id}`);
			const owner = players.find((p) => p.playerId === decision.playerId)!;
			if (decision.kind === 'hit_or_stay') {
				const cards = view.players.find((p) => p.id === owner.playerId)!.row.length;
				await owner.paced({ type: decision.canStay && cards >= 3 ? 'stay' : 'hit', decisionId: decision.id });
			} else {
				await owner.paced({ type: 'choose', decisionId: decision.id, targetId: decision.targets[0] });
			}
		}
		try {
			await observer.nextUpdate();
		} catch (error) {
			// Report every player's errors, not just the observer's, so a refused move is visible.
			const errors = players.map((p) => p.received.filter((m) => typeof m !== 'string' && m.type === 'error'));
			throw new Error(
				`${(error as Error).message.slice(0, 120)}; errors by player: ${JSON.stringify(errors)}; log: ${log.slice(-8).join(' | ')}`,
			);
		}
		view = observer.drain();
	}
	throw new Error('game did not end');
}

/** Answers target choices and skips breaks until someone has a Hit/Stay turn, and returns that view. */
async function untilTurn(code: string, players: Client[]): Promise<PublicView> {
	const observer = players[0]!;
	let view = observer.drain();
	for (let i = 0; i < 50; i++) {
		const decision = view.decision;
		if ((view.phase === 'dealing' || view.phase === 'turns') && decision?.kind === 'hit_or_stay') return view;
		if (decision && decision.kind !== 'hit_or_stay') {
			await players
				.find((p) => p.playerId === decision.playerId)!
				.paced({ type: 'choose', decisionId: decision.id, targetId: decision.targets[0] });
		} else if (view.phase === 'round_over') {
			await timeTravel(code, (room, now) => {
				room.state.nextRoundAt = now - 1;
			});
		}
		await observer.nextUpdate();
		view = observer.drain();
	}
	throw new Error('no Hit/Stay turn came up');
}

describe('a full game (PRD M2: playable from a test client)', () => {
	it('plays to the end, goes back to the room, and starts a new game with a newcomer', async () => {
		const code = await createRoom();
		const players = [await Client.join(code, 'Ali'), await Client.join(code, 'Sara'), await Client.join(code, 'Omar')];
		const [host] = players as [Client, Client, Client];
		host.send({ type: 'settings', mode: 'normal', targetScore: 100 });
		host.send({ type: 'start' });

		const results = await playToEnd(code, players);
		expect(results.outcome?.winnerIds.length).toBeGreaterThan(0);
		expect(Math.max(...results.players.map((p) => p.total))).toBeGreaterThanOrEqual(100);

		// Until someone is back in the room, newcomers wait (Rules §12.9).
		const early = await Client.connect(code);
		expect(await early.hello('Noura')).toBe('ROOM_BUSY');

		// Once one player is back, they can join, even while others are still on the results screen.
		host.send({ type: 'continue' });
		await host.nextUpdate((u) => u.view.players.find((p) => p.id === host.playerId)?.returned === true);
		const noura = await Client.join(code, 'Noura');
		const waiting = await host.nextUpdate((u) => u.view.players.some((p) => p.nickname === 'Noura'));
		expect(waiting.view.phase).toBe('results');
		expect(waiting.view.outcome?.playerIds).not.toContain(noura.playerId);

		for (const p of players.slice(1)) p.send({ type: 'continue' });
		await host.nextUpdate((u) => u.view.phase === 'lobby');
		host.send({ type: 'start' });
		const started = await noura.nextUpdate((u) => u.view.round === 1);
		expect(started.view.players.map((p) => p.total)).toEqual([0, 0, 0, 0]);
		expect(started.view.players.map((p) => p.nickname)).toEqual(['Ali', 'Sara', 'Omar', 'Noura']);
	}, 60_000);

	it('refuses joins once a game has started', async () => {
		const code = await createRoom();
		const host = await Client.join(code, 'Ali');
		await Client.join(code, 'Sara');
		host.send({ type: 'start' });
		await host.nextUpdate((u) => u.view.round === 1);
		const late = await Client.connect(code);
		expect(await late.hello('Late')).toBe('GAME_STARTED');
	});
});

describe('moves (PRD §8.6)', () => {
	async function started() {
		const code = await createRoom();
		const ali = await Client.join(code, 'Ali');
		const sara = await Client.join(code, 'Sara');
		const omar = await Client.join(code, 'Omar');
		ali.send({ type: 'start' });
		await ali.nextUpdate((u) => u.view.round === 1);
		const all = [ali, sara, omar];
		const view = await untilTurn(code, all);
		return { code, all, view, owner: all.find((c) => c.playerId === view.decision!.playerId)! };
	}

	it('refuses a decision id that was already used', async () => {
		const { owner, view } = await started();
		const id = view.decision!.id;
		owner.send({ type: 'hit', decisionId: id });
		await owner.nextUpdate((u) => u.events.some((e) => e.type === 'cardDealt' && e.source === 'hit'));
		owner.send({ type: 'hit', decisionId: id });
		expect(await owner.nextError()).toBe('STALE');
	});

	it('accepts a valid move right after an unrelated change, like another player disconnecting', async () => {
		const { all, owner, view } = await started();
		const other = all.find((c) => c !== owner)!;
		other.close();
		await owner.nextUpdate((u) => u.events.some((e) => e.type === 'playerDisconnected'));
		owner.send({ type: 'hit', decisionId: view.decision!.id });
		const update = await owner.nextUpdate((u) => u.events.some((e) => e.type === 'cardDealt' && e.to === owner.playerId));
		expect(update.events[0]!.type).toBe('cardDealt');
	});

	it('only lets the owner answer a decision', async () => {
		const { all, owner, view } = await started();
		const other = all.find((c) => c !== owner)!;
		other.send({ type: 'hit', decisionId: view.decision!.id });
		expect(await other.nextError()).toBe('NOT_ALLOWED');
	});
});

describe('removing players (PRD §4.4)', () => {
	it('closes the removed player’s socket with REMOVED, and blocks their device', async () => {
		const code = await createRoom();
		const host = await Client.join(code, 'Ali');
		const sara = await Client.join(code, 'Sara');
		host.send({ type: 'remove', playerId: sara.playerId });
		expect(await sara.nextError()).toBe('REMOVED');
		expect((await sara.waitClosed()).code).toBe(CloseCode.REFUSED);
		const again = await Client.connect(code, { deviceId: sara.deviceId });
		expect(await again.hello('Sara again')).toBe('REMOVED');
		const withToken = await Client.connect(code, { deviceId: sara.deviceId });
		expect(await withToken.hello('Sara', sara.token)).toBe('REMOVED');
	});

	it('is refused during a game', async () => {
		const code = await createRoom();
		const host = await Client.join(code, 'Ali');
		const sara = await Client.join(code, 'Sara');
		host.send({ type: 'start' });
		await host.nextUpdate((u) => u.view.round === 1);
		host.send({ type: 'remove', playerId: sara.playerId });
		expect(await host.nextError()).toBe('NOT_ALLOWED');
	});
});

describe('connections (Rules §12.3–12.5)', () => {
	async function twoPlayerGame() {
		const code = await createRoom();
		const ali = await Client.join(code, 'Ali');
		const sara = await Client.join(code, 'Sara');
		ali.send({ type: 'start' });
		await ali.nextUpdate((u) => u.view.round === 1);
		await settle();
		return { code, ali, sara };
	}

	it('a player who reconnects within the grace period gets their seat and the current state back', async () => {
		const { code, ali, sara } = await twoPlayerGame();
		sara.close();
		await ali.nextUpdate((u) => u.events.some((e) => e.type === 'playerDisconnected'));
		const back = await Client.join(code, 'Sara', { token: sara.token, deviceId: sara.deviceId });
		expect(back.playerId).toBe(sara.playerId);
		const update = await back.nextUpdate();
		expect(update.view.round).toBe(1);
		expect(update.view.players.find((p) => p.id === sara.playerId)!.connected).toBe(true);
	});

	it('a second connection with the same token replaces the first', async () => {
		const { code, sara } = await twoPlayerGame();
		const second = await Client.join(code, 'Sara', { token: sara.token, deviceId: sara.deviceId });
		expect(second.playerId).toBe(sara.playerId);
		expect((await sara.waitClosed()).code).toBe(CloseCode.REPLACED);
		await settle();
		const room = await stored(code);
		expect(room!.state.players.find((p) => p.id === sara.playerId)!.connected).toBe(true);
	});

	it('removes a player whose grace period runs out; their token then gets SEAT_LOST', async () => {
		const { code, ali, sara } = await twoPlayerGame();
		sara.close();
		await ali.nextUpdate((u) => u.events.some((e) => e.type === 'playerDisconnected'));
		await timeTravel(code, (room, now) => {
			room.state.players.find((p) => p.id === sara.playerId)!.disconnectedAt = now - GRACE_MS - 1;
		});
		// Only two players: the one left wins.
		const over = await ali.nextUpdate((u) => u.view.phase === 'results');
		expect(over.view.outcome?.winnerIds).toEqual([ali.playerId]);
		const back = await Client.connect(code, { deviceId: sara.deviceId });
		expect(await back.hello('Sara', sara.token)).toBe('SEAT_LOST');
	});

	it('pauses when everyone disconnects, and abandons the game after 5 minutes', async () => {
		const { code, ali, sara } = await twoPlayerGame();
		ali.close();
		sara.close();
		await settle(80);
		expect((await stored(code))!.state.phase).toBe('paused');
		await timeTravel(code, (room, now) => {
			room.state.pausedAt = now - PAUSE_MS - 1;
		});
		expect((await stored(code))!.state.phase).toBe('abandoned');
	});

	it('times out a turn through the alarm', async () => {
		const { code, ali, sara } = await twoPlayerGame();
		const view = await untilTurn(code, [ali, sara]);
		await timeTravel(code, (room, now) => {
			room.state.decision!.deadline = now - 1;
		});
		const update = await ali.nextUpdate((u) => u.events.some((e) => e.type === 'autoHit' || e.type === 'autoStayed'));
		expect(update.view.decision?.id).not.toBe(view.decision!.id);
	});
});

describe('durability (PRD §8.3)', () => {
	it('survives being evicted from memory with sockets hibernated: state and connections carry on', async () => {
		const code = await createRoom();
		const ali = await Client.join(code, 'Ali');
		const sara = await Client.join(code, 'Sara');
		ali.send({ type: 'start' });
		await ali.nextUpdate((u) => u.view.round === 1);
		const view = await untilTurn(code, [ali, sara]);
		const version = (await stored(code))!.state.version;
		await settle();
		await evictDurableObject(roomStub(code));

		const owner = [ali, sara].find((c) => c.playerId === view.decision!.playerId)!;
		owner.send({ type: 'hit', decisionId: view.decision!.id });
		const after = await owner.nextUpdate((u) => u.events.some((e) => e.type === 'cardDealt' && e.source === 'hit'));
		expect(after.version).toBeGreaterThan(version);
		expect(after.view.round).toBe(1);
	});

	it('deletes a room nobody has been connected to for 10 minutes', async () => {
		const code = await createRoom();
		expect(await stored(code)).toBeDefined();
		await timeTravel(code, (room, now) => {
			room.emptySince = now - EMPTY_ROOM_TTL_MS - 1;
		});
		expect(await stored(code)).toBeUndefined();
		const client = await Client.connect(code);
		expect(await client.hello('Ali')).toBe('ROOM_NOT_FOUND');
	});

	it('keeps a room alive while someone is connected', async () => {
		const code = await createRoom();
		await Client.join(code, 'Ali');
		await settle();
		expect((await stored(code))!.emptySince).toBeUndefined();
	});
});

describe('abuse (PRD §8.5)', () => {
	it('drops messages over the rate limit and closes connections that keep going', async () => {
		const code = await createRoom();
		const client = await Client.join(code, 'Ali');
		// The test limit is 200 per second (see vitest.config.mts); 30 strikes past it closes the socket.
		for (let i = 0; i < 260; i++) client.send({ type: 'continue' });
		expect((await client.waitClosed()).code).toBe(CloseCode.RATE_LIMITED);
	});
});
