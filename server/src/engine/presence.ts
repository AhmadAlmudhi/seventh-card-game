/** Connections, leaving, pausing and returning (Rules §12.3–12.5, PRD §4.6). */
import { GRACE_MS, PAUSE_MS, RETURN_MS, ROUND_BREAK_MS } from './constants';
import { dropFromRoom, passHostIfNeeded, reopenIfEveryoneBack } from './lobby';
import { findPlayer, getPlayer, isActive } from './players';
import { pick } from './rng';
import { advance, checkLastStanding, decisionDuration, giveSecondChance, removeFromDeal, resolveAction } from './round';
import { emit, type Ctx, type ErrorCode, type GameState, type Phase, type Player, type SystemAction } from './state';

/** Phases where a game is being played (including the break between rounds). */
export function isPlaying(phase: Phase): boolean {
	return phase === 'dealing' || phase === 'turns' || phase === 'round_over';
}

export function disconnect(ctx: Ctx, playerId: string): ErrorCode | undefined {
	const { s, env } = ctx;
	const player = findPlayer(s, playerId);
	if (!player) return 'UNKNOWN_PLAYER';
	if (!player.connected || player.status === 'left') return undefined;
	player.connected = false;
	player.disconnectedAt = env.now;
	emit(ctx, { type: 'playerDisconnected', playerId });

	// Rules §12.5: if every player is disconnected, pause instead of letting the game run on.
	if (isPlaying(s.phase) && !s.players.some((p) => p.connected && p.status !== 'left')) {
		s.pausedFrom = s.phase;
		s.phase = 'paused';
		s.pausedAt = env.now;
		emit(ctx, { type: 'gamePaused' });
	}
	return undefined;
}

export function reconnect(ctx: Ctx, playerId: string): ErrorCode | undefined {
	const { s, env } = ctx;
	const player = findPlayer(s, playerId);
	if (!player) return 'UNKNOWN_PLAYER';
	// Rules §12.4: a player who left can't rejoin that game.
	if (player.status === 'left') return 'NOT_ALLOWED';
	if (player.connected) return undefined;
	player.connected = true;
	player.disconnectedAt = undefined;
	emit(ctx, { type: 'playerReconnected', playerId });

	// Rules §12.5: continue once at least 2 players are back. Anyone still missing gets a fresh
	// grace period from now, and the open decision gets a fresh timer.
	const connected = s.players.filter((p) => p.connected && p.status !== 'left').length;
	if (s.phase === 'paused' && connected >= 2) {
		s.phase = s.pausedFrom ?? 'turns';
		s.pausedFrom = undefined;
		s.pausedAt = undefined;
		for (const p of s.players) if (!p.connected && p.status !== 'left') p.disconnectedAt = env.now;
		if (s.decision) s.decision.deadline = env.now + decisionDuration(s.decision);
		if (s.phase === 'round_over') s.nextRoundAt = env.now + ROUND_BREAK_MS;
		emit(ctx, { type: 'gameResumed' });
		advance(ctx);
	}
	return undefined;
}

/** Rules §12.3: the 2-minute grace period ran out. Not counted while the game is paused. */
export function graceExpired(ctx: Ctx, playerId: string): ErrorCode | undefined {
	const { s, env } = ctx;
	const player = findPlayer(s, playerId);
	if (!player) return 'UNKNOWN_PLAYER';
	if (player.connected || player.disconnectedAt === undefined || player.status === 'left') return 'NOT_ALLOWED';
	if (s.phase === 'paused') return 'NOT_ALLOWED';
	if (env.now < player.disconnectedAt + GRACE_MS) return 'TOO_EARLY';
	quit(ctx, playerId);
	return undefined;
}

/** Rules §12.5: fewer than 2 players came back within 5 minutes, so the game ends with no result. */
export function pauseExpired(ctx: Ctx): ErrorCode | undefined {
	const { s, env } = ctx;
	if (s.phase !== 'paused' || s.pausedAt === undefined) return 'NOT_ALLOWED';
	if (env.now < s.pausedAt + PAUSE_MS) return 'TOO_EARLY';
	s.phase = 'abandoned';
	s.pausedAt = undefined;
	s.pausedFrom = undefined;
	s.tasks = [];
	s.decision = undefined;
	s.nextRoundAt = undefined;
	emit(ctx, { type: 'gameAbandoned' });
	return undefined;
}

/** PRD §4.6: after 60 seconds on the results screen, everyone still there is moved into the room. */
export function returnTimeout(ctx: Ctx): ErrorCode | undefined {
	const { s, env } = ctx;
	if (s.phase !== 'results' || s.resultsAt === undefined) return 'NOT_ALLOWED';
	if (env.now < s.resultsAt + RETURN_MS) return 'TOO_EARLY';
	for (const p of s.players) {
		if (p.returned) continue;
		p.returned = true;
		emit(ctx, { type: 'playerReturned', playerId: p.id });
	}
	reopenIfEveryoneBack(ctx);
	return undefined;
}

/** The Quit button (Rules §12.4), also used when a grace period runs out. */
export function quit(ctx: Ctx, playerId: string): ErrorCode | undefined {
	const { s } = ctx;
	const player = findPlayer(s, playerId);
	if (!player) return 'UNKNOWN_PLAYER';
	if (isPlaying(s.phase) || s.phase === 'paused') leaveGame(ctx, player);
	else dropFromRoom(ctx, player, 'left');
	return undefined;
}

/**
 * Rules §12.4: the player is out for the rest of the game. Their cards stay on the table until the
 * round ends, they score 0 this round, can't be targeted, and stay on the scoreboard as "Left".
 */
function leaveGame(ctx: Ctx, player: Player): void {
	const { s } = ctx;
	if (player.status === 'left') return;
	player.status = 'left';
	player.connected = false;
	player.disconnectedAt = undefined;
	emit(ctx, { type: 'playerLeft', playerId: player.id });
	passHostIfNeeded(ctx, player);
	removeFromDeal(s, player.id);
	settleDecisionAfterLeave(ctx, player);

	if (checkLastStanding(ctx)) return;
	if (s.phase === 'dealing' || s.phase === 'turns') advance(ctx);
}

/** Rules §12.4: any prompt the leaver still had is picked at random right away. */
function settleDecisionAfterLeave(ctx: Ctx, leaver: Player): void {
	const { s, env } = ctx;
	const decision = s.decision;
	if (!decision) return;

	if (decision.kind === 'hit_or_stay') {
		if (decision.playerId === leaver.id) s.decision = undefined; // Their turn just ends.
		return;
	}

	const drawer = getPlayer(s, decision.playerId);
	const targets = decision.targets.filter((id) => id !== leaver.id && isActive(getPlayer(s, id)));

	if (decision.playerId !== leaver.id && targets.length === decision.targets.length) return;
	s.decision = undefined;

	if (targets.length === 0) {
		// Nobody can take the card any more: it goes to the table (Freeze, Flip Three) or the discard pile.
		if (decision.kind === 'choose_target') drawer.played.push(decision.card);
		else {
			s.discard.push(decision.card);
			emit(ctx, { type: 'secondChanceDiscarded', by: drawer.id, card: decision.card });
		}
		return;
	}
	if (decision.playerId !== leaver.id && targets.length > 1) {
		s.decision = { ...decision, targets };
		return;
	}
	const target = decision.playerId === leaver.id ? pick(targets, env.rng) : targets[0]!;
	if (decision.kind === 'choose_target') resolveAction(ctx, drawer, decision.card, target);
	else giveSecondChance(ctx, drawer, decision.card, target);
}

/** Every system action that is due at `now`, in no particular order. */
export function dueActions(s: GameState, now: number): Array<{ at: number; action: SystemAction }> {
	const due: Array<{ at: number; action: SystemAction }> = [];
	for (const item of scheduled(s)) if (item.at <= now) due.push(item);
	return due.sort((a, b) => a.at - b.at);
}

/** The earliest time anything is scheduled, for the room's single alarm (PRD §8.3). */
export function nextDeadline(s: GameState): number | undefined {
	const times = scheduled(s).map((item) => item.at);
	return times.length > 0 ? Math.min(...times) : undefined;
}

function scheduled(s: GameState): Array<{ at: number; action: SystemAction }> {
	const items: Array<{ at: number; action: SystemAction }> = [];
	if (s.phase === 'paused') {
		if (s.pausedAt !== undefined) items.push({ at: s.pausedAt + PAUSE_MS, action: { type: 'pauseExpired' } });
		return items;
	}
	if (s.decision && (s.phase === 'dealing' || s.phase === 'turns')) {
		items.push({ at: s.decision.deadline, action: { type: 'timeout', decisionId: s.decision.id } });
	}
	if (s.phase === 'round_over' && s.nextRoundAt !== undefined) items.push({ at: s.nextRoundAt, action: { type: 'nextRound' } });
	if (s.phase === 'results' && s.resultsAt !== undefined) items.push({ at: s.resultsAt + RETURN_MS, action: { type: 'returnTimeout' } });
	if (s.phase !== 'abandoned') {
		for (const p of s.players) {
			if (!p.connected && p.disconnectedAt !== undefined && p.status !== 'left') {
				items.push({ at: p.disconnectedAt + GRACE_MS, action: { type: 'graceExpired', playerId: p.id } });
			}
		}
	}
	return items;
}
