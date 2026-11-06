/** Cards and decks (Rules §3). */

export type PlusAmount = 2 | 4 | 6 | 8 | 10;
export type ActionKind = 'freeze' | 'flip_three' | 'second_chance';

export type NumberCard = { id: string; kind: 'number'; value: number };
export type PlusCard = { id: string; kind: 'plus'; amount: PlusAmount };
export type TimesTwoCard = { id: string; kind: 'x2' };
export type ActionCard = { id: string; kind: 'action'; action: ActionKind };
export type ModifierCard = PlusCard | TimesTwoCard;
export type Card = NumberCard | PlusCard | TimesTwoCard | ActionCard;

export const DECK_SIZE = 94;
export const PLUS_AMOUNTS: readonly PlusAmount[] = [2, 4, 6, 8, 10];
export const ACTION_KINDS: readonly ActionKind[] = ['freeze', 'flip_three', 'second_chance'];

/**
 * One full 94-card deck in a fixed order: 79 number cards, 6 modifiers, 9 actions.
 * Card ids are `d<deckNo>-<index>`, so cards stay distinct when a second deck joins (Rules §9.2).
 */
export function buildDeck(deckNo: number): Card[] {
	let index = 0;
	const id = () => `d${deckNo}-${index++}`;
	const cards: Card[] = [{ id: id(), kind: 'number', value: 0 }];
	for (let value = 1; value <= 12; value++) {
		for (let copy = 0; copy < value; copy++) cards.push({ id: id(), kind: 'number', value });
	}
	for (const amount of PLUS_AMOUNTS) cards.push({ id: id(), kind: 'plus', amount });
	cards.push({ id: id(), kind: 'x2' });
	for (const action of ACTION_KINDS) {
		for (let copy = 0; copy < 3; copy++) cards.push({ id: id(), kind: 'action', action });
	}
	return cards;
}

/** A card's type, without its id: `n0`–`n12`, `p2`–`p10`, `x2`, or the action name. */
export function cardKey(card: Card): string {
	switch (card.kind) {
		case 'number':
			return `n${card.value}`;
		case 'plus':
			return `p${card.amount}`;
		case 'x2':
			return 'x2';
		case 'action':
			return card.action;
	}
}

/** Every card type, in the order the card counter shows them. */
export const CARD_KEYS: readonly string[] = [
	...Array.from({ length: 13 }, (_, value) => `n${value}`),
	...PLUS_AMOUNTS.map((amount) => `p${amount}`),
	'x2',
	...ACTION_KINDS,
];

/** How many cards of each type are in `cards`. Every type is present, with 0 when absent. */
export function countByKey(cards: readonly Card[]): Record<string, number> {
	const counts: Record<string, number> = Object.fromEntries(CARD_KEYS.map((key) => [key, 0]));
	for (const card of cards) counts[cardKey(card)]! += 1;
	return counts;
}
