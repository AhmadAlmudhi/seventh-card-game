import { describe, expect, it } from 'vitest';
import { publicView } from '../../src/engine/engine';
import { lobby, play } from './helpers';

describe('public view (PRD §8.5)', () => {
	it('never contains the deck order, tokens, device ids or the blocked list', () => {
		const game = play(3, [5, 6, 7]);
		game.state.blockedDevices.push('blocked-device');
		const json = JSON.stringify(publicView(game.state));
		for (const card of game.state.deck) expect(json).not.toContain(`"${card.id}"`);
		for (const p of game.state.players) {
			expect(json).not.toContain(p.token);
			expect(json).not.toContain(p.deviceId);
		}
		expect(json).not.toContain('blocked-device');
	});

	it('shows the deck and discard pile as counts per card type', () => {
		const game = play(2, [5, 6]);
		const view = publicView(game.state);
		expect(view.deck.total).toBe(92);
		expect(Object.values(view.deck.counts).reduce((a, b) => a + b, 0)).toBe(92);
		expect(view.deck.counts.n5).toBe(4);
		expect(view.discard.total).toBe(0);
	});

	it('shows each player’s round score so far, the forced line, and whose turn it is', () => {
		const game = play(2, [5, 6, 'x2'], { mode: 'hard', targetScore: 400 });
		game.hit();
		const view = publicView(game.state);
		expect(view.forcedLine).toBe(300);
		expect(view.players.map((p) => p.roundScore)).toEqual([10, 6]);
		expect(view.turnPlayerId).toBe('p2');
		expect(view.decision?.playerId).toBe('p2');
	});

	it('works for an empty lobby', () => {
		expect(publicView(lobby(0).state).players).toEqual([]);
	});
});
