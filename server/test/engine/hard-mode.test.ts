import { describe, expect, it } from 'vitest';
import { ofType, play } from './helpers';

describe('Hard Mode (Rules §11)', () => {
	/** Round 1 is a quick 1 and 2, then p1 starts round 2 on `p1Total`. Round 2: Dealer p1, so the deal goes p2, p1. */
	function secondRound(p1Total: number, round2: Parameters<typeof play>[1]) {
		const game = play(2, [1, 2, ...round2], { mode: 'hard', targetScore: 400 });
		game.stay();
		game.stay();
		game.player('p1').total = p1Total;
		game.nextRound();
		return game;
	}

	it('a forced player with 3 or fewer number cards draws automatically, then chooses at 4', () => {
		const game = secondRound(300, [9, 3, 4, 5, 6]);
		expect(game.player('p1').forced).toBe(true);
		expect(game.player('p2').forced).toBe(false);
		game.stay(); // p2
		// p1 has 1 number card: the game draws 4, 5 and 6 with no prompt.
		expect(game.row('p1')).toEqual([3, 4, 5, 6]);
		const forcedTurns = ofType(game.log, 'turnStarted').filter((e) => e.playerId === 'p1' && e.forced);
		expect(forcedTurns).toHaveLength(3);
		expect(game.decision).toMatchObject({ kind: 'hit_or_stay', playerId: 'p1', canStay: true });
	});

	it('a player below the line is not forced', () => {
		const game = secondRound(299, [9, 3, 4]);
		expect(game.player('p1').forced).toBe(false);
	});

	it('a forced player may Freeze themselves', () => {
		const game = secondRound(300, [9, 3, 10, 'freeze']);
		game.hit(); // p2 takes the 10 and stays active
		// p1 is forced: the game draws the Freeze for them, and they choose who gets it.
		expect(game.decision).toMatchObject({ kind: 'choose_target', playerId: 'p1', targets: ['p1', 'p2'] });
		game.choose('p1');
		expect(game.player('p1').status).toBe('frozen');
	});

	it('a bust costs 5 points, and totals can go below zero', () => {
		const game = play(2, [5, 6, 5], { mode: 'hard', targetScore: 400 });
		game.hit(); // p1 busts
		const scored = ofType(game.stay(), 'roundScored')[0]!;
		expect(scored.scores[0]).toEqual({ playerId: 'p1', roundScore: -5, total: -5 });
	});

	it('a bust can drop a player under the line, so they aren’t forced next round', () => {
		const game = secondRound(302, [9, 3, 3, 5, 6]);
		game.stay(); // p2
		expect(game.player('p1').status).toBe('busted'); // forced draw of a second 3
		expect(game.player('p1').total).toBe(297);
		game.nextRound();
		expect(game.player('p1').forced).toBe(false);
	});

	it('a forced player who times out or disconnects with 3 or fewer cards still just draws', () => {
		const game = secondRound(300, [9, 3, 4, 5, 6]);
		game.act({ type: 'disconnect', playerId: 'p1' });
		game.stay(); // p2
		expect(game.row('p1')).toEqual([3, 4, 5, 6]);
	});
});
