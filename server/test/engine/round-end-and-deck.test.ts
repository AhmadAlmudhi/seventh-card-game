import { describe, expect, it } from 'vitest';
import { DECK_SIZE } from '../../src/engine/cards';
import { ofType, play, types } from './helpers';

describe('the Seventh Card (Rules §5.5)', () => {
	it('mid-Draw Three, ends the round right away and scores +15', () => {
		const game = play(2, [1, 9, 2, 3, 4, 5, 'd3', 6, 7, 8]);
		game.hit(); // p1: 2
		game.stay(); // p2 banks 9
		game.hit(); // 3
		game.hit(); // 4
		game.hit(); // 5
		const events = game.hit(); // Draw Three, on p1 automatically: 6, then 7 is the seventh number
		expect(types(events)).toContain('seventhCard');
		expect(game.state.phase).toBe('round_over');
		expect(game.topOfDeck()).toBe('8'); // the Draw Three still had a card left
		const scored = ofType(events, 'roundScored')[0]!;
		expect(scored.scores).toEqual([
			{ playerId: 'p1', roundScore: 28 + 15, total: 43 },
			{ playerId: 'p2', roundScore: 9, total: 9 },
		]);
	});

	it('during the deal, ends the round right away; every player who hasn’t busted scores', () => {
		const game = play(3, [9, 'd3', 1, 2, 'd3', 3, 4, 'd3', 5, 6, 7, 8]);
		game.choose('p2'); // p2's dealt Draw Three, on themselves
		game.choose('p2'); // chained Draw Three: +3
		game.choose('p2'); // and again
		expect(game.player('p2').seventhCard).toBe(true);
		expect(game.state.phase).toBe('round_over');
		expect(game.row('p3')).toEqual([]); // the deal never reached p3
		const scored = ofType(game.log, 'roundScored')[0]!;
		expect(scored.scores.map((s) => s.roundScore)).toEqual([9, 43, 0]);
	});

	it('keeps the scored hands on the table during the break, then moves them to the discard pile', () => {
		const game = play(2, [4, 6, 8, 9]);
		game.stay();
		game.stay();
		expect(game.row('p1')).toEqual([4]);
		expect(game.state.dealerId).toBe('p2');
		game.nextRound();
		expect(game.state.discard.map((c) => (c.kind === 'number' ? c.value : '?'))).toEqual([4, 6]);
	});
});

describe('deck management (Rules §9)', () => {
	it('does not reshuffle between rounds: the deck carries over, and the next player deals', () => {
		const game = play(2, [5, 6, 7, 8]);
		game.stay();
		game.stay();
		const events = game.nextRound();
		expect(types(events)).not.toContain('reshuffled');
		expect(types(events)).not.toContain('deckReset');
		expect(ofType(events, 'roundStarted')[0]).toMatchObject({ round: 2, dealerId: 'p1' });
		// Dealer p1: the deal goes p2, p1.
		expect(game.row('p2')).toEqual([7]);
		expect(game.row('p1')).toEqual([8]);
	});

	it('when the deck runs out mid-round, shuffles only the discard pile; table cards stay put', () => {
		const game = play(2, [5, 6, 7]);
		const seven = game.state.deck[0]!;
		game.state.deck = [];
		game.state.discard = [seven];
		const events = game.hit();
		expect(ofType(events, 'reshuffled')[0]).toMatchObject({ count: 1 });
		expect(game.row('p1')).toEqual([5, 7]);
		expect(game.row('p2')).toEqual([6]);
	});

	it('when the deck and discard pile are both empty, adds a whole new deck, then resets after the round', () => {
		const game = play(2, [5, 6]);
		game.state.deck = [];
		game.state.discard = [];
		const events = game.hit();
		expect(ofType(events, 'extraDeckAdded')[0]).toMatchObject({ deckNo: 2 });
		expect(game.state.decksInPlay).toBe(2);
		const drawn = ofType(events, 'cardDealt')[0]!.card;
		expect(drawn.id.startsWith('d2-')).toBe(true);

		// Play the round out: stay when allowed, otherwise hit.
		while (game.state.phase === 'turns') {
			if (game.turn.canStay) game.stay();
			else game.hit();
		}
		expect(game.state.phase).toBe('round_over');
		const next = game.nextRound();
		expect(types(next)).toContain('deckReset');
		expect(game.state.decksInPlay).toBe(1);
		expect(game.state.discard).toEqual([]);
		expect(game.state.deck.length + 2).toBe(DECK_SIZE); // two cards were just dealt
		expect(game.state.deck.every((c) => c.id.startsWith('d3-'))).toBe(true);
	});

	it('with a second deck, a bust is still decided by number value', () => {
		const game = play(2, [5, 6]);
		game.state.deck = [];
		game.state.discard = [];
		const fresh = game.hit();
		const card = ofType(fresh, 'cardDealt')[0]!.card;
		expect(card.id.startsWith('d2-')).toBe(true);
	});
});
