import { publicView } from '../../src/engine/engine';
import { describe, expect, it } from 'vitest';
import { ofType, play } from './helpers';

describe('end of the game (Rules §10.1)', () => {
	it('is checked only at the end of a round, and the highest total wins', () => {
		const game = play(2, [10, 12], { targetScore: 100 });
		game.player('p1').total = 95;
		game.player('p2').total = 98;
		game.stay(); // p1 will reach 105...
		expect(game.state.phase).toBe('turns'); // ...but nothing is decided mid-round
		const events = game.stay(); // p2 reaches 110
		expect(ofType(events, 'gameOver')[0]).toEqual({ type: 'gameOver', winnerIds: ['p2'], draw: false });
		expect(game.state.phase).toBe('results');
		expect(game.state.outcome).toMatchObject({ winnerIds: ['p2'], draw: false });
	});

	it('keeps playing rounds while nobody has reached the winning score', () => {
		const game = play(2, [10, 12], { targetScore: 100 });
		game.stay();
		game.stay();
		expect(game.state.phase).toBe('round_over');
		expect(game.state.nextRoundAt).toBe(game.now + 4000);
	});
});

describe('tie-breaks (Rules §10.2)', () => {
	function tiedGame() {
		const game = play(3, [10, 10, 5], { targetScore: 100 });
		game.player('p1').total = 90;
		game.player('p2').total = 90;
		game.player('p3').total = 50;
		game.stay();
		game.stay();
		game.stay();
		return game;
	}

	it('starts with only the tied players, on a fresh deck, with the others watching', () => {
		const game = tiedGame();
		expect(ofType(game.log, 'tiebreakStarted')[0]).toMatchObject({ playerIds: ['p1', 'p2'], roundNo: 1 });
		expect(game.state.phase).toBe('round_over');

		const events = game.nextRound();
		expect(ofType(events, 'deckReset')).toHaveLength(1);
		expect(ofType(events, 'roundStarted')[0]!.playerIds).toEqual(['p1', 'p2']);
		expect(game.player('p3').status).toBe('watching');
		expect(['p1', 'p2']).toContain(game.state.dealerId);
		expect(game.state.discard).toEqual([]);
	});

	it('is decided by that round’s score alone, and leaves totals unchanged', () => {
		const game = tiedGame();
		game.nextRound([7, 9], 'p2'); // Dealer p2: the deal goes p1, p2
		game.stay();
		const events = game.stay();
		expect(ofType(events, 'gameOver')[0]).toMatchObject({ winnerIds: ['p2'], draw: false });
		expect([game.player('p1').total, game.player('p2').total]).toEqual([100, 100]);
		expect(game.state.outcome?.tiebreakRounds).toBe(1);
	});

	it('drops players who fall behind, rotates the Dealer, and ends in a draw after 3 tied rounds', () => {
		const game = play(3, [10, 10, 10], { targetScore: 100 });
		for (const id of ['p1', 'p2', 'p3']) game.player(id).total = 90;
		game.stay();
		game.stay();
		game.stay();

		expect(publicView(game.state).scoredTiebreakRound).toBeUndefined();

		game.nextRound([7, 7, 5], 'p3'); // tie-break 1, Dealer p3: p1 7, p2 7, p3 5
		game.stay();
		game.stay();
		game.stay();
		expect(ofType(game.log, 'tiebreakStarted')[1]).toMatchObject({ playerIds: ['p1', 'p2'], roundNo: 2 });
		// The break after a tie-break round says so, because its scores didn't change totals.
		expect(publicView(game.state).scoredTiebreakRound).toBe(1);

		game.nextRound([8, 8]); // tie-break 2: the next tied player after p3 deals, which is p1
		expect(game.state.dealerId).toBe('p1');
		expect(game.player('p3').status).toBe('watching');
		game.stay();
		game.stay();

		game.nextRound([6, 6]); // tie-break 3: p2 deals
		expect(game.state.dealerId).toBe('p2');
		game.stay();
		const events = game.stay();
		expect(ofType(events, 'gameOver')[0]).toEqual({ type: 'gameOver', winnerIds: ['p1', 'p2'], draw: true });
		expect(game.state.outcome?.tiebreakRounds).toBe(3);
	});

	it('the last tied player still in the game wins if the others leave', () => {
		const game = tiedGame();
		game.nextRound([7, 9], 'p2');
		const events = game.act({ type: 'quit', by: 'p2' });
		expect(ofType(events, 'gameOver')[0]).toMatchObject({ winnerIds: ['p1'] });
	});
});
