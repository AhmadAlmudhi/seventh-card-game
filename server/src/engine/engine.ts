/**
 * The rules engine's entry point (PRD §8.4). Pure: no network, storage or timers. The room turns
 * messages, sockets and alarms into actions; this module turns actions into a new state plus the
 * events that explain what happened.
 */
import { DEFAULT_TARGET_SCORE } from './constants';
import { changeSettings, continueToRoom, join, removePlayer, start } from './lobby';
import { disconnect, graceExpired, pauseExpired, quit, reconnect, returnTimeout } from './presence';
import { choose, hit, nextRound, stay, timeout, type NextRoundOptions, type StartOptions } from './round';
import type { Action, Ctx, EngineEnv, ErrorCode, GameEvent, GameState } from './state';

export type ApplyResult = { ok: true; state: GameState; events: GameEvent[] } | { ok: false; error: ErrorCode };

/** A new, empty room in the lobby, with Normal Mode settings. */
export function createRoom(): GameState {
	return {
		phase: 'lobby',
		settings: { mode: 'normal', targetScore: DEFAULT_TARGET_SCORE.normal },
		players: [],
		blockedDevices: [],
		round: 0,
		roundPlayerIds: [],
		deck: [],
		discard: [],
		decksInPlay: 1,
		nextDeckNo: 1,
		tasks: [],
		nextDecisionNo: 1,
		version: 0,
	};
}

/**
 * Applies one action. Never changes `state`: on success it returns a new state and the events, in
 * order; on failure it returns an error code and the caller keeps the old state.
 */
export function applyAction(state: GameState, action: Action, env: EngineEnv): ApplyResult {
	return run(state, env, (ctx) => dispatch(ctx, action));
}

/** Like the `start` action, but with a prepared deck and Dealer. For tests only. */
export function startWith(state: GameState, by: string, env: EngineEnv, opts: StartOptions): ApplyResult {
	return run(state, env, (ctx) => start(ctx, by, opts));
}

/** Like the `nextRound` action, but with a prepared fresh deck and tie-break Dealer. For tests only. */
export function nextRoundWith(state: GameState, env: EngineEnv, opts: NextRoundOptions): ApplyResult {
	return run(state, env, (ctx) => nextRound(ctx, opts));
}

function run(state: GameState, env: EngineEnv, step: (ctx: Ctx) => ErrorCode | undefined): ApplyResult {
	// The state is plain JSON data, and a JSON round-trip copies it about a third faster than structuredClone.
	const ctx: Ctx = { s: JSON.parse(JSON.stringify(state)) as GameState, env, events: [] };
	const error = step(ctx);
	if (error) return { ok: false, error };
	return { ok: true, state: ctx.s, events: ctx.events };
}

function dispatch(ctx: Ctx, action: Action): ErrorCode | undefined {
	switch (action.type) {
		case 'join':
			return join(ctx, action);
		case 'settings':
			return changeSettings(ctx, action.by, action.mode, action.targetScore);
		case 'start':
			return start(ctx, action.by);
		case 'hit':
			return hit(ctx, action.by, action.decisionId);
		case 'stay':
			return stay(ctx, action.by, action.decisionId);
		case 'choose':
			return choose(ctx, action.by, action.decisionId, action.targetId);
		case 'continue':
			return continueToRoom(ctx, action.by);
		case 'remove':
			return removePlayer(ctx, action.by, action.playerId);
		case 'quit':
			return quit(ctx, action.by);
		case 'timeout':
			return timeout(ctx, action.decisionId);
		case 'disconnect':
			return disconnect(ctx, action.playerId);
		case 'reconnect':
			return reconnect(ctx, action.playerId);
		case 'graceExpired':
			return graceExpired(ctx, action.playerId);
		case 'pauseExpired':
			return pauseExpired(ctx);
		case 'returnTimeout':
			return returnTimeout(ctx);
		case 'nextRound':
			return nextRound(ctx);
	}
}

export { dueActions, nextDeadline } from './presence';
export { publicView, type PublicView, type PublicPlayer } from './view';
export type * from './state';
