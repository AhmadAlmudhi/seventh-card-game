/** Tutorial rooms over the real Worker and WebSocket (PRD §4.9). */
import { SELF } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import { BOT_ID, TUTORIAL_TARGET_SCORE } from '../../src/engine/constants';
import { Client, SITE, settle, stored, timeTravel } from './client';

const BASE = 'https://server.test';

async function createTutorial(): Promise<string> {
	const response = await SELF.fetch(`${BASE}/api/rooms`, {
		method: 'POST',
		headers: { Origin: SITE, 'Content-Type': 'application/json' },
		body: JSON.stringify({ tutorial: true }),
	});
	expect(response.status).toBe(201);
	return ((await response.json()) as { code: string }).code;
}

describe('tutorial rooms (PRD §4.9)', () => {
	it('starts a game against the bot as soon as the player joins', async () => {
		const code = await createTutorial();
		const ali = await Client.join(code, 'Ali');
		const update = await ali.nextUpdate();
		expect(update.view.tutorial).toBe(true);
		expect(update.view.settings).toEqual({ mode: 'normal', targetScore: TUTORIAL_TARGET_SCORE });
		expect(update.view.players.map((p) => p.id).sort()).toEqual([BOT_ID, ali.playerId!].sort());
		expect(['dealing', 'turns']).toContain(update.view.phase);
		expect(update.view.lastDraw).toBeDefined();
		ali.close();
	});

	it('lets nobody else in', async () => {
		const code = await createTutorial();
		const ali = await Client.join(code, 'Ali');
		const sara = await Client.connect(code);
		expect(await sara.hello('Sara')).toBe('GAME_STARTED');
		ali.close();
	});

	it('plays the bot on the room alarm', async () => {
		const code = await createTutorial();
		const ali = await Client.join(code, 'Ali');
		await ali.nextUpdate();
		// Answer Ali's own decisions until it's the bot's turn to decide.
		for (let i = 0; i < 20; i++) {
			const view = ali.drain();
			const decision = view.decision;
			if (decision?.playerId === BOT_ID) break;
			if (!decision) {
				await timeTravel(code, (room, now) => {
					if (room.state.nextRoundAt !== undefined) room.state.nextRoundAt = now - 1;
				});
			} else if (decision.kind === 'hit_or_stay') {
				ali.send({ type: decision.canStay ? 'stay' : 'hit', decisionId: decision.id });
			} else {
				ali.send({ type: 'choose', decisionId: decision.id, targetId: decision.targets[0] });
			}
			await ali.nextUpdate();
		}
		const decision = ali.view.decision;
		expect(decision?.playerId).toBe(BOT_ID);
		ali.drain();
		await timeTravel(code, (room, now) => {
			room.state.decision!.deadline = now - 1;
		});
		const after = await ali.nextUpdate();
		expect(after.view.decision?.id).not.toBe(decision!.id);
		expect(after.events.some((e) => e.type === 'cardDealt' || e.type === 'stayed' || e.type === 'actionPlayed')).toBe(true);
		ali.close();
	});

	it('is cleaned up once its player has gone, even though the bot is always "connected"', async () => {
		const code = await createTutorial();
		const ali = await Client.join(code, 'Ali');
		await ali.nextUpdate();
		ali.send({ type: 'quit' });
		await ali.waitClosed();
		await settle();
		const room = await stored(code);
		expect(room?.state.phase).toBe('results');
		expect(room?.emptySince).toBeDefined();
	});

	it('refuses a malformed request body', async () => {
		for (const body of ['{"tutorial":"yes"}', '{"other":true}', 'not json']) {
			const response = await SELF.fetch(`${BASE}/api/rooms`, { method: 'POST', headers: { Origin: SITE }, body });
			expect(response.status).toBe(400);
		}
	});
});
