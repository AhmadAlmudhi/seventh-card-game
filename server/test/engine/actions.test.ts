import { describe, expect, it } from 'vitest';
import { ofType, play } from './helpers';

describe('targeting (Rules §6.1)', () => {
	it('targets the Drawer automatically when they are the only active player, with no prompt', () => {
		const game = play(2, [3, 4, 'freeze']);
		game.stay(); // p1
		const events = game.hit(); // p2 draws the Freeze while alone
		expect(ofType(events, 'decisionRequested').filter((e) => e.decision.kind === 'choose_target')).toEqual([]);
		expect(ofType(events, 'actionPlayed')[0]).toMatchObject({ by: 'p2', target: 'p2' });
		expect(game.player('p2').status).toBe('frozen');
	});

	it('only offers active players as targets', () => {
		const game = play(3, [3, 4, 5, 6, 'freeze']);
		game.stay(); // p1 stays
		game.hit(); // p2 takes the 6
		game.hit(); // p3 draws the Freeze
		expect(game.decision).toMatchObject({ kind: 'choose_target', playerId: 'p3', targets: ['p2', 'p3'] });
		expect(game.reject({ type: 'choose', by: 'p3', decisionId: game.decision.id, targetId: 'p1' })).toBe('INVALID_TARGET');
	});
});

describe('Freeze (Rules §6.2)', () => {
	it('freezes another player, who banks their points', () => {
		const game = play(2, [3, 4, 'freeze']);
		game.hit(); // p1 draws the Freeze
		game.choose('p2');
		expect(game.player('p2').status).toBe('frozen');
		expect(game.decision.playerId).toBe('p1');
		const scored = ofType(game.stay(), 'roundScored')[0]!;
		expect(scored.scores.map((s) => s.roundScore)).toEqual([3, 4]);
	});

	it('can freeze yourself', () => {
		const game = play(2, [3, 4, 'freeze']);
		game.hit();
		game.choose('p1');
		expect(game.player('p1').status).toBe('frozen');
		expect(game.decision.playerId).toBe('p2');
	});

	it('freezing the last active player ends the round', () => {
		const game = play(2, [3, 4, 'freeze']);
		game.hit();
		game.choose('p1');
		game.stay(); // p2 stays: nobody is active
		expect(game.state.phase).toBe('round_over');
	});

	it('a frozen player with only modifiers banks them: +6 scores 6, x2 alone scores 0', () => {
		const game = play(3, ['+6', 'x2', 'freeze', 'freeze', 7]);
		// The deal gives p1 +6, p2 x2 and p3 a Freeze.
		game.choose('p1'); // p3 freezes p1, who holds only +6
		game.hit(); // p2 (only x2) must hit, and draws the second Freeze
		game.choose('p2'); // p2 freezes themselves
		expect(game.decision).toMatchObject({ playerId: 'p3', canStay: false }); // p3 has no number card yet
		game.hit(); // p3 takes the 7
		const scored = ofType(game.stay(), 'roundScored')[0]!;
		expect(scored.scores.map((s) => [s.playerId, s.roundScore])).toEqual([
			['p1', 6],
			['p2', 0],
			['p3', 7],
		]);
	});
});

describe('Flip Three (Rules §6.3)', () => {
	it('counts every card type toward the 3', () => {
		const game = play(2, [5, 6, 'f3', '+4', 'x2', 7, 8]);
		game.hit();
		game.choose('p1');
		expect(game.row('p1')).toEqual([5, 7]);
		expect(game.player('p1').modifiers.map((c) => c.kind)).toEqual(['plus', 'x2']);
		expect(game.topOfDeck()).toBe('8');
		expect(ofType(game.log, 'flipThreeEnded')[0]).toMatchObject({ playerId: 'p1', reason: 'done' });
		expect(game.decision.playerId).toBe('p2');
	});

	it('stops early on a bust', () => {
		const game = play(2, [5, 6, 'f3', 9, 5, 8]);
		game.hit();
		game.choose('p1');
		expect(game.player('p1').status).toBe('busted');
		expect(game.topOfDeck()).toBe('8');
		expect(ofType(game.log, 'flipThreeEnded')[0]).toMatchObject({ reason: 'busted' });
	});

	it('stops for each action card and waits for it to be used', () => {
		const game = play(2, [5, 6, 'f3', 'freeze', 3, 4]);
		game.hit();
		game.choose('p1');
		expect(game.decision).toMatchObject({ kind: 'choose_target', playerId: 'p1' });
		expect(game.state.tasks.at(-1)).toMatchObject({ t: 'flipThree', playerId: 'p1', remaining: 2 });
		game.choose('p2');
		expect(game.player('p2').status).toBe('frozen');
		expect(game.row('p1')).toEqual([5, 3, 4]);
	});

	it('is cancelled when its target is frozen', () => {
		const game = play(2, [5, 6, 'f3', 'freeze', 3, 4]);
		game.hit();
		game.choose('p1');
		game.choose('p1'); // the Freeze, on themselves
		expect(game.player('p1').status).toBe('frozen');
		expect(game.topOfDeck()).toBe('3');
		expect(ofType(game.log, 'flipThreeEnded')[0]).toMatchObject({ reason: 'frozen' });
	});

	it('inside a Flip Three, played on yourself, adds 3 to the cards left', () => {
		const game = play(2, [5, 6, 'f3', 1, 'f3', 2, 3, 4, 7, 8]);
		game.hit();
		game.choose('p1');
		// Card 2 is the second Flip Three: 1 card left + 3 = 4 more.
		game.choose('p1');
		expect(game.row('p1')).toEqual([5, 1, 2, 3, 4, 7]);
		expect(game.topOfDeck()).toBe('8');
	});

	it('inside a Flip Three, played on someone else, finishes first; then the original continues', () => {
		const game = play(3, [5, 6, 7, 'f3', 1, 'f3', 2, 3, 4, 8, 9]);
		game.hit(); // p1
		game.choose('p1');
		game.choose('p2'); // the second Flip Three goes to p2
		expect(
			ofType(game.log, 'cardDealt')
				.map((e) => `${e.to}:${e.source}`)
				.slice(3),
		).toEqual(['p1:hit', 'p1:flipThree', 'p1:flipThree', 'p2:flipThree', 'p2:flipThree', 'p2:flipThree', 'p1:flipThree']);
		expect(game.row('p2')).toEqual([6, 2, 3, 4]);
		expect(game.row('p1')).toEqual([5, 1, 8]);
		expect(game.topOfDeck()).toBe('9');
	});

	it('…and that player can Freeze the original player to end their Flip Three', () => {
		const game = play(3, [5, 6, 7, 'f3', 1, 'f3', 'freeze', 2, 3, 4]);
		game.hit();
		game.choose('p1');
		game.choose('p2');
		game.choose('p1'); // p2 freezes p1 during p2's Flip Three
		expect(game.row('p2')).toEqual([6, 2, 3]);
		expect(game.player('p1').status).toBe('frozen');
		expect(game.topOfDeck()).toBe('4');
	});
});

describe('Second Chance (Rules §6.4)', () => {
	it('is kept automatically, and on a duplicate both cards are discarded and the player stays in', () => {
		const game = play(2, ['sc', 9, 5, 5]);
		game.hit(); // p1 takes the 5
		game.stay(); // p2
		const events = game.hit(); // p1 draws the duplicate 5
		expect(ofType(events, 'secondChanceUsed')).toHaveLength(1);
		expect(game.player('p1')).toMatchObject({ status: 'active', secondChance: undefined });
		expect(game.row('p1')).toEqual([5]);
		expect(game.state.discard.map((c) => (c.kind === 'number' ? c.value : c.kind))).toEqual(['action', 5]);
	});

	it('without one, a duplicate busts the player, whose cards stay on the table', () => {
		const game = play(2, [5, 9, 5]);
		game.hit();
		expect(game.player('p1').status).toBe('busted');
		expect(game.row('p1')).toEqual([5]);
		expect(game.player('p1').bustCard?.value).toBe(5);
		const scored = ofType(game.stay(), 'roundScored')[0]!;
		expect(scored.scores[0]).toMatchObject({ playerId: 'p1', roundScore: 0 });
	});

	it('a second one must be given to an eligible player, chosen by the Drawer', () => {
		const game = play(4, ['sc', 7, 8, 9, 'sc']);
		game.hit();
		expect(game.decision).toMatchObject({ kind: 'give_second_chance', playerId: 'p1', targets: ['p2', 'p3', 'p4'] });
		game.choose('p3');
		expect(game.player('p3').secondChance).toBeDefined();
		expect(game.player('p1').secondChance).toBeDefined();
	});

	it('goes to the only eligible player automatically', () => {
		const game = play(3, ['sc', 'sc', 8, 'sc']);
		game.hit();
		expect(game.player('p3').secondChance).toBeDefined();
		expect(ofType(game.log, 'secondChanceGiven')[0]).toMatchObject({ by: 'p1', to: 'p3' });
	});

	it('is discarded when nobody is eligible', () => {
		const game = play(2, ['sc', 'sc', 'sc']);
		game.hit();
		expect(ofType(game.log, 'secondChanceDiscarded')).toHaveLength(1);
		expect(game.state.discard).toHaveLength(1);
	});

	it('drawn during a Flip Three can save the player later in the same Flip Three', () => {
		const game = play(2, [5, 6, 'f3', 'sc', 5, 7]);
		game.hit();
		game.choose('p1');
		expect(game.player('p1')).toMatchObject({ status: 'active' });
		expect(game.row('p1')).toEqual([5, 7]);
	});

	it('unused ones are discarded when the round ends', () => {
		const game = play(2, ['sc', 4, 5]);
		game.hit();
		game.stay();
		game.stay();
		game.nextRound();
		expect(game.player('p1').secondChance).toBeUndefined();
		expect(game.state.discard.some((c) => c.kind === 'action' && c.action === 'second_chance')).toBe(true);
	});
});
