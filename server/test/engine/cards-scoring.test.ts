import { describe, expect, it } from 'vitest';
import { buildDeck, countByKey, DECK_SIZE, type ModifierCard, type NumberCard } from '../../src/engine/cards';
import { forcedLine, scoreHand } from '../../src/engine/scoring';

describe('deck (Rules §3)', () => {
	const deck = buildDeck(1);
	const counts = countByKey(deck);

	it('has 79 number cards, 6 modifiers and 9 actions: 94 in total', () => {
		expect(deck).toHaveLength(DECK_SIZE);
		expect(deck.filter((c) => c.kind === 'number')).toHaveLength(79);
		expect(deck.filter((c) => c.kind === 'plus' || c.kind === 'x2')).toHaveLength(6);
		expect(deck.filter((c) => c.kind === 'action')).toHaveLength(9);
	});

	it('has each number as many times as its value, and one 0', () => {
		expect(counts.n0).toBe(1);
		for (let value = 1; value <= 12; value++) expect(counts[`n${value}`]).toBe(value);
	});

	it('has one each of +2, +4, +6, +8, +10 and x2, and three of each action', () => {
		for (const key of ['p2', 'p4', 'p6', 'p8', 'p10', 'x2']) expect(counts[key]).toBe(1);
		for (const key of ['freeze', 'flip_three', 'second_chance']) expect(counts[key]).toBe(3);
	});

	it('gives every card a unique id that includes its deck number', () => {
		const ids = new Set([...deck, ...buildDeck(2)].map((c) => c.id));
		expect(ids.size).toBe(2 * DECK_SIZE);
		expect(deck.every((c) => c.id.startsWith('d1-'))).toBe(true);
	});
});

const n = (...values: number[]): NumberCard[] => values.map((value, i) => ({ id: `n${i}`, kind: 'number', value }));
const plus = (amount: 2 | 4 | 6 | 8 | 10): ModifierCard => ({ id: `p${amount}-${Math.random()}`, kind: 'plus', amount });
const x2 = (): ModifierCard => ({ id: `x2-${Math.random()}`, kind: 'x2' });

describe('scoring (Rules §8)', () => {
	it('3, 11, 5, 7, 10, 9, 4 with the Seventh Card scores 49 + 15 = 64', () => {
		expect(scoreHand({ row: n(3, 11, 5, 7, 10, 9, 4), modifiers: [], seventhCard: true })).toBe(64);
	});

	it('11, 5, 12 with x2 and +4 scores 28 × 2 + 4 = 60', () => {
		expect(scoreHand({ row: n(11, 5, 12), modifiers: [x2(), plus(4)], seventhCard: false })).toBe(60);
	});

	it('two x2 multiply: 10, 8 with two x2 scores 18 × 4 = 72', () => {
		expect(scoreHand({ row: n(10, 8), modifiers: [x2(), x2()], seventhCard: false })).toBe(72);
	});

	it('matching + modifiers both count: two +10 add 20', () => {
		expect(scoreHand({ row: n(5), modifiers: [plus(10), plus(10)], seventhCard: false })).toBe(25);
	});

	it('modifiers alone still score: +6 alone is 6, x2 alone is 0', () => {
		expect(scoreHand({ row: [], modifiers: [plus(6)], seventhCard: false })).toBe(6);
		expect(scoreHand({ row: [], modifiers: [x2()], seventhCard: false })).toBe(0);
	});

	it('x2 never doubles + modifiers or the Seventh Card bonus', () => {
		expect(scoreHand({ row: n(1, 2, 3, 4, 5, 6, 0), modifiers: [x2(), plus(2)], seventhCard: true })).toBe(21 * 2 + 2 + 15);
	});

	it('the 0 counts as a number card but scores nothing', () => {
		expect(scoreHand({ row: n(0, 5), modifiers: [], seventhCard: false })).toBe(5);
	});
});

describe('Hard Mode forced-Hit line (Rules §11.1)', () => {
	it('is 75% of the winning score, rounded down', () => {
		expect([200, 300, 400, 500, 1000].map(forcedLine)).toEqual([150, 225, 300, 375, 750]);
		expect(forcedLine(150)).toBe(112);
	});
});
