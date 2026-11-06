/**
 * Playing a game: rounds, the deal, turns, card effects, scoring and the end of the game.
 * Rule references are to game_rules.md.
 */
import { botMove } from './bot';
import { buildDeck, type ActionCard, type Card } from './cards';
import {
	BOT_CHOOSE_MS,
	BOT_HIT_OR_STAY_MS,
	CHOOSE_MS,
	FORCED_MAX_NUMBER_CARDS,
	HIT_OR_STAY_MS,
	MAX_TIEBREAK_ROUNDS,
	ROUND_BREAK_MS,
	SEVENTH_CARD_COUNT,
	TUTORIAL_DECISION_MS,
} from './constants';
import { activeIds, bySeat, getPlayer, isActive, orderAfter, remainingPlayers } from './players';
import { pick, shuffle } from './rng';
import { forcedLine, roundScore } from './scoring';
import { emit, type CardSource, type Ctx, type Decision, type ErrorCode, type GameState, type Player } from './state';

/** Distributes Omit over a union, so each decision kind keeps its own fields. */
type DistributiveOmit<T, K extends PropertyKey> = T extends unknown ? Omit<T, K> : never;

export interface StartOptions {
	/** Use this deck (top first) instead of a shuffled one. For tests. */
	deck?: Card[];
	/** Use this first Dealer instead of a random one. For tests. */
	firstDealerId?: string;
}

// ---------------------------------------------------------------------------
// Starting games and rounds
// ---------------------------------------------------------------------------

/** Rules §4: fixed seat order, one shuffled deck, a random first Dealer, every total at 0. */
export function startGame(ctx: Ctx, opts: StartOptions = {}): void {
	const { s, env } = ctx;
	const seated = bySeat(s.players);
	seated.forEach((p, seat) => {
		p.seat = seat;
		p.total = 0;
		p.status = 'active';
		p.returned = true;
		p.roundScore = undefined;
		clearHand(p);
	});
	s.round = 0;
	s.tiebreak = undefined;
	s.scoredTiebreakRound = undefined;
	s.outcome = undefined;
	s.resultsAt = undefined;
	freshDeck(ctx, opts.deck);
	emit(ctx, { type: 'gameStarted' });
	startRound(ctx, opts.firstDealerId ?? pick(seated, env.rng).id);
}

export interface NextRoundOptions {
	/** Use this deck (top first) when the round starts with a fresh deck. For tests. */
	deck?: Card[];
	/** Use this Dealer for the first tie-break round instead of a random one. For tests. */
	dealerId?: string;
}

/** Starts the next round after the break between rounds (`nextRound` system action). */
export function nextRound(ctx: Ctx, opts: NextRoundOptions = {}): ErrorCode | undefined {
	const { s, env } = ctx;
	if (s.phase !== 'round_over' || s.nextRoundAt === undefined) return 'NOT_ALLOWED';
	if (env.now < s.nextRoundAt) return 'TOO_EARLY';
	s.nextRoundAt = undefined;
	s.scoredTiebreakRound = undefined;

	clearTable(s);
	// Rules §9.3: after a round that used a second deck, go back to one fresh deck.
	// Rules §10.2: every tie-break round starts with a fresh deck.
	if (s.tiebreak || s.decksInPlay > 1) {
		freshDeck(ctx, opts.deck);
		emit(ctx, { type: 'deckReset' });
	}

	const previousDealerSeat = s.dealerId ? getPlayer(s, s.dealerId).seat : -1;
	let dealer: Player;
	if (s.tiebreak) {
		const tied = bySeat(s.tiebreak.playerIds.map((id) => getPlayer(s, id)));
		// Rules §10.2: random Dealer for the first tie-break round, then the next tied player in seat order.
		const firstDealer = opts.dealerId ? getPlayer(s, opts.dealerId) : pick(tied, env.rng);
		dealer = s.tiebreak.roundNo === 1 ? firstDealer : orderAfter(tied, previousDealerSeat)[0]!;
	} else {
		// Rules §5.5: the next player in seat order deals, skipping players who left.
		dealer = orderAfter(remainingPlayers(s), previousDealerSeat)[0]!;
	}
	startRound(ctx, dealer.id);
	return undefined;
}

function startRound(ctx: Ctx, dealerId: string): void {
	const { s } = ctx;
	s.round += 1;
	const playing = s.tiebreak ? bySeat(s.tiebreak.playerIds.map((id) => getPlayer(s, id))) : remainingPlayers(s);
	const playingIds = new Set(playing.map((p) => p.id));
	const line = forcedLine(s.settings.targetScore);

	for (const p of s.players) {
		p.roundScore = undefined;
		p.seventhCard = false;
		p.forced = false;
		if (p.status === 'left') continue;
		if (!playingIds.has(p.id)) {
			p.status = 'watching';
			continue;
		}
		p.status = 'active';
		// Rules §11.1: forced status is fixed when the round starts.
		p.forced = s.settings.mode === 'hard' && p.total >= line;
	}

	s.roundPlayerIds = playing.map((p) => p.id);
	s.lastDraw = undefined;
	s.dealerId = dealerId;
	s.turnPlayerId = dealerId;
	emit(ctx, { type: 'roundStarted', round: s.round, dealerId, playerIds: s.roundPlayerIds, tiebreak: s.tiebreak });

	// Rules §5.1: deal starting after the Dealer, ending with the Dealer.
	const queue = orderAfter(playing, getPlayer(s, dealerId).seat).map((p) => p.id);
	s.tasks = [{ t: 'turns' }, { t: 'deal', queue }];
	s.phase = 'dealing';
	advance(ctx);
}

// ---------------------------------------------------------------------------
// The task loop
// ---------------------------------------------------------------------------

/**
 * Works through the task stack until the game needs a decision from a player or the round ends
 * (PRD §8.4). Safe to call at any time: it does nothing while a decision is open.
 */
export function advance(ctx: Ctx): void {
	const { s } = ctx;
	for (let steps = 0; ; steps++) {
		if (steps > ADVANCE_LIMIT) throw new Error(`advance did not settle: ${describeStuck(s)}`);
		if (s.decision || (s.phase !== 'dealing' && s.phase !== 'turns')) return;
		const top = s.tasks.at(-1);
		if (!top) {
			endRound(ctx);
			return;
		}

		if (top.t === 'deal') {
			s.phase = 'dealing';
			const nextId = top.queue.shift();
			if (nextId === undefined) {
				s.tasks.pop();
				continue;
			}
			const player = getPlayer(s, nextId);
			// Rules §5.1.4: players who busted or were frozen during the deal are skipped.
			if (isActive(player)) reveal(ctx, player, 'deal');
			continue;
		}

		if (top.t === 'flipThree') {
			const target = getPlayer(s, top.playerId);
			if (!isActive(target) || top.remaining === 0) {
				s.tasks.pop();
				emit(ctx, { type: 'flipThreeEnded', playerId: target.id, reason: flipThreeEndReason(target) });
				continue;
			}
			top.remaining -= 1;
			reveal(ctx, target, 'flipThree');
			continue;
		}

		// Rules §5.2: turns go around the table in seat order, skipping players who aren't active.
		s.phase = 'turns';
		const current = s.turnPlayerId ? getPlayer(s, s.turnPlayerId) : undefined;
		const next = orderAfter(s.players, current?.seat ?? -1).find(isActive);
		if (!next) {
			// Rules §5.5.1: nobody is active.
			endRound(ctx);
			return;
		}
		s.turnPlayerId = next.id;
		// Rules §11.1: a forced player with 3 or fewer number cards draws right away, with no prompt.
		const forcedHit = next.forced && next.row.length <= FORCED_MAX_NUMBER_CARDS;
		emit(ctx, { type: 'turnStarted', playerId: next.id, forced: forcedHit });
		if (forcedHit) {
			reveal(ctx, next, 'hit');
			continue;
		}
		// Rules §5.2.3: Stay needs at least one number card.
		requestDecision(ctx, { kind: 'hit_or_stay', playerId: next.id, canStay: next.row.length >= 1 });
		return;
	}
}

/**
 * A safety net: one action can never need anywhere near this many steps (a round with two full
 * decks takes a few hundred). Hitting it means a bug, and throwing beats a stuck room.
 */
const ADVANCE_LIMIT = 5_000;

function describeStuck(s: GameState): string {
	const players = s.players
		.filter((p) => p.status === 'active')
		.map((p) => `${p.id}[row ${p.row.map((c) => c.value).join(',')}; sc ${p.secondChance ? 1 : 0}; forced ${p.forced}]`);
	return `phase ${s.phase}, tasks ${JSON.stringify(s.tasks)}, active ${players.join(' ')}, deck ${s.deck.length}, discard ${s.discard.length} (${s.discard.map((c) => (c.kind === 'number' ? c.value : c.kind === 'action' ? c.action : c.kind)).join(',')}), decks ${s.decksInPlay}`;
}

function flipThreeEndReason(target: Player): 'done' | 'busted' | 'frozen' | 'left' {
	if (target.status === 'busted') return 'busted';
	if (target.status === 'frozen') return 'frozen';
	if (target.status === 'left') return 'left';
	return 'done';
}

function requestDecision(ctx: Ctx, decision: DistributiveOmit<Decision, 'id' | 'deadline'>): void {
	const { s, env } = ctx;
	const full = { ...decision, id: `q${s.nextDecisionNo++}`, deadline: 0 } as Decision;
	full.deadline = env.now + decisionDuration(s, full);
	s.decision = full;
	emit(ctx, { type: 'decisionRequested', decision: full });
}

/**
 * How long a decision gets on the clock (Rules §12.2). In the tutorial (PRD §4.9), the bot answers
 * when its short "thinking" time runs out, and the player gets a long timer instead of a turn timer.
 */
export function decisionDuration(s: GameState, decision: Decision): number {
	const hitOrStay = decision.kind === 'hit_or_stay';
	if (getPlayer(s, decision.playerId).bot) return hitOrStay ? BOT_HIT_OR_STAY_MS : BOT_CHOOSE_MS;
	if (s.tutorial) return TUTORIAL_DECISION_MS;
	return hitOrStay ? HIT_OR_STAY_MS : CHOOSE_MS;
}

// ---------------------------------------------------------------------------
// Drawing and revealing cards
// ---------------------------------------------------------------------------

/** Rules §9.1–9.2: reshuffle the discard pile when the deck runs out, or add a whole new deck. */
function draw(ctx: Ctx): Card {
	const { s, env } = ctx;
	if (s.deck.length === 0) {
		if (s.discard.length > 0) {
			s.deck = shuffle(s.discard, env.rng);
			s.discard = [];
			emit(ctx, { type: 'reshuffled', count: s.deck.length });
		} else {
			const deckNo = s.nextDeckNo++;
			s.deck = shuffle(buildDeck(deckNo), env.rng);
			s.decksInPlay += 1;
			emit(ctx, { type: 'extraDeckAdded', deckNo });
		}
	}
	return s.deck.shift()!;
}

/** Rules §5.3: reveal the top card to `player` and apply it. */
function reveal(ctx: Ctx, player: Player, source: CardSource): void {
	const { s } = ctx;
	const card = draw(ctx);
	s.lastDraw = { card, playerId: player.id, source };
	emit(ctx, { type: 'cardDealt', to: player.id, card, source });

	switch (card.kind) {
		case 'number': {
			if (player.row.some((c) => c.value === card.value)) {
				if (player.secondChance) {
					// Rules §6.4: the Second Chance and the duplicate are both discarded.
					const secondChance = player.secondChance;
					player.secondChance = undefined;
					s.discard.push(secondChance, card);
					emit(ctx, { type: 'secondChanceUsed', playerId: player.id, card: secondChance, duplicate: card });
				} else {
					// Rules §5.4: the duplicate stays on the table with the rest of the player's cards.
					player.status = 'busted';
					player.bustCard = card;
					emit(ctx, { type: 'busted', playerId: player.id, duplicate: card });
				}
				return;
			}
			player.row.push(card);
			if (player.row.length >= SEVENTH_CARD_COUNT) {
				// Rules §5.5.2: the Seventh Card ends the round right away, even mid-Flip Three.
				player.seventhCard = true;
				emit(ctx, { type: 'seventhCard', playerId: player.id });
				endRound(ctx);
			}
			return;
		}
		case 'plus':
		case 'x2':
			player.modifiers.push(card);
			return;
		case 'action':
			playAction(ctx, player, card);
			return;
	}
}

// ---------------------------------------------------------------------------
// Action cards (Rules §6)
// ---------------------------------------------------------------------------

function playAction(ctx: Ctx, drawer: Player, card: ActionCard): void {
	const { s } = ctx;
	if (card.action === 'second_chance') {
		if (!drawer.secondChance) {
			drawer.secondChance = card;
			emit(ctx, { type: 'secondChanceKept', playerId: drawer.id, card });
			return;
		}
		const eligible = secondChanceTargets(s, drawer.id);
		if (eligible.length === 0) {
			s.discard.push(card);
			emit(ctx, { type: 'secondChanceDiscarded', by: drawer.id, card });
		} else if (eligible.length === 1) {
			giveSecondChance(ctx, drawer, card, eligible[0]!);
		} else {
			requestDecision(ctx, { kind: 'give_second_chance', playerId: drawer.id, card, targets: eligible });
		}
		return;
	}

	// Rules §6.1: any active player, including the Drawer. The only active player targets themselves.
	const targets = activeIds(s);
	if (targets.length <= 1) {
		resolveAction(ctx, drawer, card, targets[0] ?? drawer.id);
		return;
	}
	requestDecision(ctx, { kind: 'choose_target', playerId: drawer.id, card, targets });
}

/** Rules §6.4: other active players without a Second Chance. */
export function secondChanceTargets(s: GameState, drawerId: string): string[] {
	return activeIds(s).filter((id) => id !== drawerId && !getPlayer(s, id).secondChance);
}

export function giveSecondChance(ctx: Ctx, drawer: Player, card: ActionCard, toId: string): void {
	getPlayer(ctx.s, toId).secondChance = card;
	emit(ctx, { type: 'secondChanceGiven', by: drawer.id, to: toId, card });
}

/** Applies a Freeze or Flip Three to its target. */
export function resolveAction(ctx: Ctx, drawer: Player, card: ActionCard, targetId: string): void {
	const { s } = ctx;
	const target = getPlayer(s, targetId);
	drawer.played.push(card);
	emit(ctx, { type: 'actionPlayed', by: drawer.id, target: targetId, card });

	// Rules §5.1.3: a player hit by Freeze or Flip Three before their first card doesn't get one later.
	removeFromDeal(s, targetId);

	if (!isActive(target)) return; // The target left while the choice was open.

	if (card.action === 'freeze') {
		// Rules §6.2: the target banks their points and is out for the round.
		target.status = 'frozen';
		emit(ctx, { type: 'frozen', playerId: targetId, by: drawer.id });
		return;
	}

	// Rules §6.3: on yourself mid-Flip Three, add 3 to the cards left; otherwise the target's
	// Flip Three goes on top of the stack and finishes first.
	const top = s.tasks.at(-1);
	if (top?.t === 'flipThree' && top.playerId === targetId) {
		top.remaining += 3;
		emit(ctx, { type: 'flipThreeStarted', playerId: targetId, by: drawer.id, remaining: top.remaining });
	} else {
		s.tasks.push({ t: 'flipThree', playerId: targetId, remaining: 3 });
		emit(ctx, { type: 'flipThreeStarted', playerId: targetId, by: drawer.id, remaining: 3 });
	}
}

export function removeFromDeal(s: GameState, playerId: string): void {
	for (const task of s.tasks) {
		if (task.t === 'deal') task.queue = task.queue.filter((id) => id !== playerId);
	}
}

// ---------------------------------------------------------------------------
// Player decisions
// ---------------------------------------------------------------------------

function openDecision(ctx: Ctx, by: string, decisionId: string): Decision | ErrorCode {
	const { s } = ctx;
	if (!s.decision || s.decision.id !== decisionId) return 'STALE';
	if (s.phase !== 'dealing' && s.phase !== 'turns') return 'NOT_ALLOWED';
	if (s.decision.playerId !== by) return 'NOT_ALLOWED';
	return s.decision;
}

export function hit(ctx: Ctx, by: string, decisionId: string): ErrorCode | undefined {
	const decision = openDecision(ctx, by, decisionId);
	if (typeof decision === 'string') return decision;
	if (decision.kind !== 'hit_or_stay') return 'NOT_ALLOWED';
	ctx.s.decision = undefined;
	reveal(ctx, getPlayer(ctx.s, by), 'hit');
	advance(ctx);
	return undefined;
}

export function stay(ctx: Ctx, by: string, decisionId: string): ErrorCode | undefined {
	const decision = openDecision(ctx, by, decisionId);
	if (typeof decision === 'string') return decision;
	if (decision.kind !== 'hit_or_stay') return 'NOT_ALLOWED';
	if (!decision.canStay) return 'CANNOT_STAY';
	ctx.s.decision = undefined;
	getPlayer(ctx.s, by).status = 'stayed';
	emit(ctx, { type: 'stayed', playerId: by });
	advance(ctx);
	return undefined;
}

export function choose(ctx: Ctx, by: string, decisionId: string, targetId: string): ErrorCode | undefined {
	const decision = openDecision(ctx, by, decisionId);
	if (typeof decision === 'string') return decision;
	if (decision.kind === 'hit_or_stay') return 'NOT_ALLOWED';
	if (!decision.targets.includes(targetId)) return 'INVALID_TARGET';
	applyChoice(ctx, decision, targetId);
	advance(ctx);
	return undefined;
}

function applyChoice(ctx: Ctx, decision: Exclude<Decision, { kind: 'hit_or_stay' }>, targetId: string): void {
	ctx.s.decision = undefined;
	const drawer = getPlayer(ctx.s, decision.playerId);
	if (decision.kind === 'choose_target') resolveAction(ctx, drawer, decision.card, targetId);
	else giveSecondChance(ctx, drawer, decision.card, targetId);
}

/**
 * Rules §12.2–12.3, the same whether the player is connected or not: Hit/Stay becomes Stay (Hit
 * only when Stay isn't allowed), and a Freeze or Flip Three goes to the Drawer themselves. An extra
 * Second Chance can't be kept, so it goes to a random eligible player. The tutorial's bot makes its
 * own move when its thinking time runs out (PRD §4.9).
 */
export function timeout(ctx: Ctx, decisionId: string): ErrorCode | undefined {
	const { s, env } = ctx;
	const decision = s.decision;
	if (!decision || decision.id !== decisionId) return 'STALE';
	if (s.phase !== 'dealing' && s.phase !== 'turns') return 'NOT_ALLOWED';
	if (env.now < decision.deadline) return 'TOO_EARLY';

	if (getPlayer(s, decision.playerId).bot) {
		const move = botMove(s, decision, env.rng);
		if (move.type === 'choose') return choose(ctx, decision.playerId, decision.id, move.targetId);
		return move.type === 'stay' ? stay(ctx, decision.playerId, decision.id) : hit(ctx, decision.playerId, decision.id);
	}

	if (decision.kind === 'hit_or_stay') {
		const player = getPlayer(s, decision.playerId);
		s.decision = undefined;
		if (decision.canStay) {
			player.status = 'stayed';
			emit(ctx, { type: 'autoStayed', playerId: player.id });
		} else {
			emit(ctx, { type: 'autoHit', playerId: player.id });
			reveal(ctx, player, 'hit');
		}
	} else if (decision.kind === 'choose_target' && decision.targets.includes(decision.playerId)) {
		applyChoice(ctx, decision, decision.playerId);
	} else {
		applyChoice(ctx, decision, pick(decision.targets, env.rng));
	}
	advance(ctx);
	return undefined;
}

// ---------------------------------------------------------------------------
// End of a round and of the game
// ---------------------------------------------------------------------------

/**
 * Rules §5.5 and §8. Scores the round and decides what comes next. The cards stay on the table
 * through the break between rounds, so every player can see the hands that were scored; they move
 * to the discard pile when the next round starts.
 */
function endRound(ctx: Ctx): void {
	const { s } = ctx;
	s.tasks = [];
	s.decision = undefined;
	s.turnPlayerId = undefined;

	s.scoredTiebreakRound = s.tiebreak?.roundNo;
	const scores = s.roundPlayerIds.map((id) => {
		const player = getPlayer(s, id);
		player.roundScore = roundScore(player, s.settings.mode);
		// Tie-break rounds decide the winner by their own score and don't change totals.
		if (!s.tiebreak) player.total += player.roundScore;
		return { playerId: id, roundScore: player.roundScore, total: player.total };
	});
	emit(ctx, { type: 'roundScored', scores });

	if (s.tiebreak) {
		settleTiebreak(ctx);
		return;
	}

	// Rules §10.1: checked only at the end of a round. The highest total wins.
	const contenders = remainingPlayers(s);
	if (contenders.some((p) => p.total >= s.settings.targetScore)) {
		const best = Math.max(...contenders.map((p) => p.total));
		const top = contenders.filter((p) => p.total === best);
		if (top.length === 1) finishGame(ctx, [top[0]!.id], false);
		else startTiebreak(ctx, top, 1);
		return;
	}
	toRoundBreak(ctx);
}

/** Rules §10.2: the tie-break round's own score decides; up to 3 rounds, then a draw. */
function settleTiebreak(ctx: Ctx): void {
	const { s } = ctx;
	const tiebreak = s.tiebreak!;
	const tied = tiebreak.playerIds.map((id) => getPlayer(s, id)).filter((p) => p.status !== 'left');
	if (tied.length === 1) {
		finishGame(ctx, [tied[0]!.id], false);
		return;
	}
	const best = Math.max(...tied.map((p) => p.roundScore ?? 0));
	const top = tied.filter((p) => (p.roundScore ?? 0) === best);
	if (top.length === 1) finishGame(ctx, [top[0]!.id], false);
	else if (tiebreak.roundNo >= MAX_TIEBREAK_ROUNDS)
		finishGame(
			ctx,
			bySeat(top).map((p) => p.id),
			true,
		);
	else startTiebreak(ctx, top, tiebreak.roundNo + 1);
}

function startTiebreak(ctx: Ctx, players: Player[], roundNo: number): void {
	const playerIds = bySeat(players).map((p) => p.id);
	ctx.s.tiebreak = { roundNo, playerIds };
	emit(ctx, { type: 'tiebreakStarted', playerIds, roundNo });
	toRoundBreak(ctx);
}

function toRoundBreak(ctx: Ctx): void {
	ctx.s.phase = 'round_over';
	ctx.s.nextRoundAt = ctx.env.now + ROUND_BREAK_MS;
}

export function finishGame(ctx: Ctx, winnerIds: string[], draw: boolean): void {
	const { s, env } = ctx;
	s.tasks = [];
	s.decision = undefined;
	s.turnPlayerId = undefined;
	s.nextRoundAt = undefined;
	s.pausedAt = undefined;
	s.pausedFrom = undefined;
	s.tiebreak = undefined;
	s.phase = 'results';
	s.resultsAt = env.now;
	s.outcome = { winnerIds, draw, playerIds: s.players.map((p) => p.id), tiebreakRounds: s.scoredTiebreakRound ?? 0 };
	// Players who left, and the tutorial's bot, don't need to tap Continue.
	for (const p of s.players) p.returned = p.status === 'left' || p.bot === true;
	emit(ctx, { type: 'gameOver', winnerIds, draw });
}

/**
 * Rules §12.1: the game keeps going while 2 or more players are left. During a tie-break, the last
 * tied player still in the game wins (Rules §10.2.7). Returns true if the game ended.
 */
export function checkLastStanding(ctx: Ctx): boolean {
	const { s } = ctx;
	const remaining = remainingPlayers(s);
	if (remaining.length === 1) {
		finishGame(ctx, [remaining[0]!.id], false);
		return true;
	}
	if (s.tiebreak) {
		const tied = s.tiebreak.playerIds.filter((id) => getPlayer(s, id).status !== 'left');
		if (tied.length === 1) {
			finishGame(ctx, tied, false);
			return true;
		}
	}
	return false;
}

// ---------------------------------------------------------------------------
// Table and deck housekeeping
// ---------------------------------------------------------------------------

function freshDeck(ctx: Ctx, deck?: Card[]): void {
	const { s, env } = ctx;
	const deckNo = s.nextDeckNo++;
	s.deck = deck ?? shuffle(buildDeck(deckNo), env.rng);
	s.discard = [];
	s.decksInPlay = 1;
}

/** Rules §5.5.2–3: unused Second Chances and every card on the table go to the discard pile. */
function clearTable(s: GameState): void {
	for (const p of s.players) s.discard.push(...clearHand(p));
}

function clearHand(p: Player): Card[] {
	const cards: Card[] = [...p.row, ...p.modifiers, ...p.played];
	if (p.secondChance) cards.push(p.secondChance);
	if (p.bustCard) cards.push(p.bustCard);
	p.row = [];
	p.modifiers = [];
	p.played = [];
	p.secondChance = undefined;
	p.bustCard = undefined;
	return cards;
}
