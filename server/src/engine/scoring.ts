/** Scoring (Rules §8, §11). */
import { FORCED_LINE_RATIO, HARD_MODE_BUST_SCORE, SEVENTH_CARD_BONUS } from './constants';
import type { ModifierCard, NumberCard } from './cards';
import type { Mode, Player } from './state';

export interface Hand {
	row: readonly NumberCard[];
	modifiers: readonly ModifierCard[];
	seventhCard: boolean;
}

/**
 * (sum of number cards × 2^(x2 cards)) + (sum of + modifiers) + (15 for the Seventh Card).
 * x2 never doubles the + modifiers or the bonus.
 */
export function scoreHand(hand: Hand): number {
	const numbers = hand.row.reduce((sum, card) => sum + card.value, 0);
	let doublings = 0;
	let plus = 0;
	for (const card of hand.modifiers) {
		if (card.kind === 'x2') doublings += 1;
		else plus += card.amount;
	}
	return numbers * 2 ** doublings + plus + (hand.seventhCard ? SEVENTH_CARD_BONUS : 0);
}

/** A player's score for the round that just ended. */
export function roundScore(player: Player, mode: Mode): number {
	if (player.status === 'left') return 0;
	if (player.status === 'busted') return mode === 'hard' ? HARD_MODE_BUST_SCORE : 0;
	return scoreHand(player);
}

/** Hard Mode forced-Hit line: 75% of the winning score, rounded down (Rules §11.1). */
export function forcedLine(targetScore: number): number {
	return Math.floor(targetScore * FORCED_LINE_RATIO);
}
