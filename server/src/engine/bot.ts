/**
 * The tutorial's computer player (PRD §4.9). It plays a fair, readable game: it only uses what
 * every player can see (the cards on the table and the card counter's totals), never the deck order.
 */
import { cardKey, type Card } from './cards';
import { getPlayer } from './players';
import type { Rng } from './rng';
import { scoreHand } from './scoring';
import type { Decision, GameState, Player } from './state';

export type BotMove = { type: 'hit' } | { type: 'stay' } | { type: 'choose'; targetId: string };

/** What the bot does with an open decision of its own. */
export function botMove(s: GameState, decision: Decision, rng: Rng): BotMove {
	const me = getPlayer(s, decision.playerId);
	if (decision.kind === 'hit_or_stay') return shouldStay(s, me, decision.canStay, rng) ? { type: 'stay' } : { type: 'hit' };

	const others = decision.targets.filter((id) => id !== me.id).map((id) => getPlayer(s, id));
	if (decision.kind === 'give_second_chance') return { type: 'choose', targetId: lowestTotal(others).id };

	if (decision.card.action === 'freeze') {
		// Bank its own points when it has a decent round going and the next card looks risky;
		// otherwise stop the opponent who is furthest ahead.
		const banks = decision.targets.includes(me.id) && scoreHand(me) >= 15 && bustRisk(s, me) >= 0.25;
		if (banks || others.length === 0) return { type: 'choose', targetId: me.id };
		return { type: 'choose', targetId: highestTotal(others).id };
	}
	// Flip Three: push the opponent with the most to lose this round.
	if (others.length === 0) return { type: 'choose', targetId: me.id };
	const target = others.reduce((best, p) => (scoreHand(p) > scoreHand(best) ? p : best));
	return { type: 'choose', targetId: target.id };
}

function shouldStay(s: GameState, me: Player, canStay: boolean, rng: Rng): boolean {
	if (!canStay) return false;
	const score = scoreHand(me);
	// Reaching the winning score ends the game in its favour if it stays ahead, so bank it.
	if (me.total + score >= s.settings.targetScore) return true;
	const risk = bustRisk(s, me);
	const comfortable = 22 + rng.int(8);
	return score >= comfortable || (risk >= 0.3 && score >= 12) || risk >= 0.45;
}

/**
 * The chance the next card duplicates a number this player holds, from the public counts of the
 * pile the next card comes from. A Second Chance makes a bust much less likely.
 */
export function bustRisk(s: GameState, me: Player): number {
	const pile: readonly Card[] = s.deck.length > 0 ? s.deck : s.discard;
	if (pile.length === 0) return 0;
	const held = new Set(me.row.map((card) => cardKey(card)));
	let duplicates = 0;
	for (const card of pile) if (held.has(cardKey(card))) duplicates += 1;
	const risk = duplicates / pile.length;
	return me.secondChance ? risk * 0.2 : risk;
}

function highestTotal(players: Player[]): Player {
	return players.reduce((best, p) => (p.total > best.total ? p : best));
}

function lowestTotal(players: Player[]): Player {
	return players.reduce((best, p) => (p.total < best.total ? p : best));
}
