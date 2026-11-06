/**
 * What every player sees (Rules §12.7, PRD §8.5). Everything on the table is public, so the same
 * view goes to everyone. Left out: the deck order, tokens, device ids and the blocked list.
 */
import { countByKey, type ActionCard, type Card, type ModifierCard, type NumberCard } from './cards';
import { forcedLine, roundScore, scoreHand } from './scoring';
import type { Decision, GameState, LastDraw, Outcome, Phase, PlayerStatus, Settings, Tiebreak } from './state';

export interface PublicPlayer {
	id: string;
	nickname: string;
	seat: number;
	total: number;
	connected: boolean;
	status: PlayerStatus;
	row: NumberCard[];
	modifiers: ModifierCard[];
	secondChance?: ActionCard;
	played: ActionCard[];
	bustCard?: NumberCard;
	seventhCard: boolean;
	forced: boolean;
	/** This round's score so far, or the final round score once the round is scored. */
	roundScore: number;
	returned: boolean;
	/** Only set (true) for the tutorial's bot. */
	bot?: true;
}

export interface PileView {
	total: number;
	/** The card on top: the last one added. Every card in the discard pile is face up, so this is public. Never set for the deck. */
	top?: Card;
	/** How many of each card type (`n0`–`n12`, `p2`–`p10`, `x2`, actions). Never the order. */
	counts: Record<string, number>;
}

export interface PublicView {
	phase: Phase;
	settings: Settings;
	/** Only set (true) in a tutorial room (PRD §4.9). */
	tutorial?: true;
	forcedLine: number;
	players: PublicPlayer[];
	hostId?: string;
	round: number;
	roundPlayerIds: string[];
	dealerId?: string;
	turnPlayerId?: string;
	tiebreak?: Tiebreak;
	decision?: Decision;
	/** The card revealed most recently this round, for the middle of the table (PRD §6.2). */
	lastDraw?: LastDraw;
	/** Draw Threes in progress, innermost last, with the cards each still has to take. */
	drawThrees: Array<{ playerId: string; remaining: number }>;
	deck: PileView;
	discard: PileView;
	decksInPlay: number;
	nextRoundAt?: number;
	/** During the break after a tie-break round: its number. Tie-break scores don't change totals (Rules §10.2). */
	scoredTiebreakRound?: number;
	resultsAt?: number;
	pausedAt?: number;
	outcome?: Outcome;
}

export function publicView(s: GameState): PublicView {
	return {
		phase: s.phase,
		settings: { ...s.settings },
		...(s.tutorial ? { tutorial: true as const } : {}),
		forcedLine: forcedLine(s.settings.targetScore),
		players: s.players
			.map((p) => ({
				id: p.id,
				nickname: p.nickname,
				seat: p.seat,
				total: p.total,
				connected: p.connected,
				status: p.status,
				row: [...p.row],
				modifiers: [...p.modifiers],
				secondChance: p.secondChance,
				played: [...p.played],
				bustCard: p.bustCard,
				seventhCard: p.seventhCard,
				forced: p.forced,
				roundScore: p.roundScore ?? liveScore(p, s),
				returned: p.returned,
				...(p.bot ? { bot: true as const } : {}),
			}))
			.sort((a, b) => a.seat - b.seat),
		hostId: s.hostId,
		round: s.round,
		roundPlayerIds: [...s.roundPlayerIds],
		dealerId: s.dealerId,
		turnPlayerId: s.turnPlayerId,
		tiebreak: s.tiebreak ? { roundNo: s.tiebreak.roundNo, playerIds: [...s.tiebreak.playerIds] } : undefined,
		decision: s.decision ? structuredClone(s.decision) : undefined,
		lastDraw: s.lastDraw ? { card: s.lastDraw.card, playerId: s.lastDraw.playerId, source: s.lastDraw.source } : undefined,
		drawThrees: s.tasks.flatMap((t) => (t.t === 'drawThree' ? [{ playerId: t.playerId, remaining: t.remaining }] : [])),
		deck: pile(s.deck),
		discard: { ...pile(s.discard), top: s.discard.at(-1) },
		decksInPlay: s.decksInPlay,
		nextRoundAt: s.nextRoundAt,
		scoredTiebreakRound: s.scoredTiebreakRound,
		resultsAt: s.resultsAt,
		pausedAt: s.pausedAt,
		outcome: s.outcome
			? {
					winnerIds: [...s.outcome.winnerIds],
					draw: s.outcome.draw,
					playerIds: [...s.outcome.playerIds],
					tiebreakRounds: s.outcome.tiebreakRounds,
				}
			: undefined,
	};
}

function liveScore(p: GameState['players'][number], s: GameState): number {
	if (p.status === 'busted' || p.status === 'left') return roundScore(p, s.settings.mode);
	return scoreHand(p);
}

function pile(cards: Card[]): PileView {
	return { total: cards.length, counts: countByKey(cards) };
}
