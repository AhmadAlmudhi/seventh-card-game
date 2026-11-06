import { describe, expect, it } from 'vitest';
import { ofType, play, types } from './helpers';

describe('the first deal (Rules §5.1)', () => {
	it('deals one card to each player, starting after the Dealer and ending with the Dealer', () => {
		const game = play(3, [5, 7, 9], { dealer: 'p1' });
		// Dealer p1: the deal goes p2, p3, p1.
		expect(ofType(game.log, 'cardDealt').map((e) => [e.to, e.source])).toEqual([
			['p2', 'deal'],
			['p3', 'deal'],
			['p1', 'deal'],
		]);
		expect([game.row('p2'), game.row('p3'), game.row('p1')]).toEqual([[5], [7], [9]]);
		// The first turn belongs to the player after the Dealer.
		expect(game.decision).toMatchObject({ kind: 'hit_or_stay', playerId: 'p2', canStay: true });
	});

	it('pauses for an action card; a player frozen before their first card gets no first card', () => {
		const game = play(3, [5, 'freeze', 9]);
		expect(game.decision).toMatchObject({ kind: 'choose_target', playerId: 'p2', targets: ['p1', 'p2', 'p3'] });
		expect(game.state.phase).toBe('dealing');

		game.choose('p3');
		expect(game.player('p3').status).toBe('frozen');
		expect(game.row('p3')).toEqual([]);
		expect(game.topOfDeck()).toBe('9'); // p3's first card was never dealt
		expect(game.decision).toMatchObject({ kind: 'hit_or_stay', playerId: 'p1' });
	});

	it('Flip Three on a player before their first card replaces their first card', () => {
		const game = play(3, ['f3', 4, 6, 8, 10]);
		game.choose('p2');
		// p2 takes the 3 Flip Three cards, then the deal skips them and continues with p3.
		expect(game.row('p2')).toEqual([4, 6, 8]);
		expect(game.row('p3')).toEqual([10]);
		expect(game.row('p1')).toEqual([]);
		expect(game.player('p1').played.map((c) => c.kind === 'action' && c.action)).toEqual(['flip_three']);
	});

	it('lets a player finish the deal with no number cards; they must Hit', () => {
		const game = play(2, ['+4', 6, 7]);
		expect(game.player('p1').modifiers).toHaveLength(1);
		expect(game.decision).toMatchObject({ playerId: 'p1', canStay: false });
		expect(game.reject({ type: 'stay', by: 'p1', decisionId: game.decision.id })).toBe('CANNOT_STAY');
		game.hit();
		expect(game.row('p1')).toEqual([7]);
	});
});

describe('turns (Rules §5.2)', () => {
	it('refuses Stay with only a Second Chance', () => {
		const game = play(2, ['sc', 5]);
		expect(game.player('p1').secondChance).toBeDefined();
		expect(game.turn.canStay).toBe(false);
		expect(game.reject({ type: 'stay', by: 'p1', decisionId: game.decision.id })).toBe('CANNOT_STAY');
	});

	it('goes around the table in seat order, skipping players who are no longer active', () => {
		const game = play(3, [1, 2, 3, 4]);
		game.stay(); // p1
		expect(game.decision.playerId).toBe('p2');
		game.hit(); // p2 takes the 4
		expect(game.row('p2')).toEqual([2, 4]);
		expect(game.decision.playerId).toBe('p3');
		game.stay(); // p3
		expect(game.decision.playerId).toBe('p2'); // p1 stayed, so it's p2 again
	});

	it('only lets the player who owns a decision answer it', () => {
		const game = play(2, [1, 2]);
		expect(game.reject({ type: 'hit', by: 'p2', decisionId: game.decision.id })).toBe('NOT_ALLOWED');
	});

	it('ends the round when nobody is active, and scores it', () => {
		const game = play(2, [1, 2]);
		game.stay();
		const events = game.stay();
		expect(types(events)).toContain('roundScored');
		expect(game.state.phase).toBe('round_over');
		expect(ofType(events, 'roundScored')[0]!.scores).toEqual([
			{ playerId: 'p1', roundScore: 1, total: 1 },
			{ playerId: 'p2', roundScore: 2, total: 2 },
		]);
	});

	it('a Hit gives one card, then the turn passes', () => {
		const game = play(2, [1, 2, 3]);
		const events = game.hit();
		expect(ofType(events, 'cardDealt').map((e) => [e.to, e.source])).toEqual([['p1', 'hit']]);
		expect(game.decision.playerId).toBe('p2');
	});
});
