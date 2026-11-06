/** The room around the game: joining, settings, starting, removing players, and coming back after a game. */
import { MAX_PLAYERS, MIN_PLAYERS, TARGET_SCORE_MAX, TARGET_SCORE_MIN, TARGET_SCORE_STEP } from './constants';
import { nicknameKey, normalizeNickname } from './nickname';
import { bySeat, findPlayer, orderAfter } from './players';
import { startGame, type StartOptions } from './round';
import { emit, type Ctx, type ErrorCode, type Mode, type Player, type PlayerAction } from './state';

type JoinAction = Extract<PlayerAction, { type: 'join' }>;

/** PRD §4.3, R-2–R-4. */
export function join(ctx: Ctx, action: JoinAction): ErrorCode | undefined {
	const { s } = ctx;
	if (s.blockedDevices.includes(action.deviceId)) return 'REMOVED';
	if (s.phase === 'results') return 'ROOM_BUSY';
	if (s.phase !== 'lobby') return 'GAME_STARTED';
	if (s.players.length >= MAX_PLAYERS) return 'ROOM_FULL';
	const nickname = normalizeNickname(action.nickname);
	if (!nickname) return 'INVALID_NICKNAME';
	if (s.players.some((p) => nicknameKey(p.nickname) === nicknameKey(nickname))) return 'NICKNAME_TAKEN';
	if (findPlayer(s, action.playerId)) return 'NOT_ALLOWED';

	const seat = s.players.reduce((max, p) => Math.max(max, p.seat), -1) + 1;
	const player: Player = {
		id: action.playerId,
		nickname,
		seat,
		token: action.token,
		deviceId: action.deviceId,
		total: 0,
		connected: true,
		status: 'active',
		row: [],
		modifiers: [],
		played: [],
		seventhCard: false,
		forced: false,
		returned: true,
	};
	s.players.push(player);
	emit(ctx, { type: 'playerJoined', playerId: player.id });
	if (!s.hostId) {
		s.hostId = player.id;
		emit(ctx, { type: 'hostChanged', playerId: player.id });
	}
	return undefined;
}

/** Rules §12.8: host only, in the lobby. */
export function changeSettings(ctx: Ctx, by: string, mode: Mode, targetScore: number): ErrorCode | undefined {
	const { s } = ctx;
	if (s.phase !== 'lobby') return 'NOT_ALLOWED';
	if (by !== s.hostId) return 'NOT_HOST';
	const validTarget =
		Number.isInteger(targetScore) &&
		targetScore >= TARGET_SCORE_MIN &&
		targetScore <= TARGET_SCORE_MAX &&
		targetScore % TARGET_SCORE_STEP === 0;
	if ((mode !== 'normal' && mode !== 'hard') || !validTarget) return 'INVALID_SETTINGS';
	s.settings = { mode, targetScore };
	emit(ctx, { type: 'settingsChanged', settings: s.settings });
	return undefined;
}

/** Host only, in the lobby, with 2–8 players (Rules §12.1). */
export function start(ctx: Ctx, by: string, opts?: StartOptions): ErrorCode | undefined {
	const { s } = ctx;
	if (s.phase !== 'lobby') return 'NOT_ALLOWED';
	if (by !== s.hostId) return 'NOT_HOST';
	if (s.players.length < MIN_PLAYERS) return 'NOT_ENOUGH_PLAYERS';
	startGame(ctx, opts);
	return undefined;
}

/** PRD §4.6: the results screen's Continue button. */
export function continueToRoom(ctx: Ctx, by: string): ErrorCode | undefined {
	const { s } = ctx;
	if (s.phase !== 'results') return 'NOT_ALLOWED';
	const player = findPlayer(s, by);
	if (!player) return 'UNKNOWN_PLAYER';
	if (!player.returned) {
		player.returned = true;
		emit(ctx, { type: 'playerReturned', playerId: by });
	}
	reopenIfEveryoneBack(ctx);
	return undefined;
}

/** PRD §4.4, R-8: host only, before or after a game, never during one. */
export function removePlayer(ctx: Ctx, by: string, playerId: string): ErrorCode | undefined {
	const { s } = ctx;
	if (s.phase !== 'lobby' && s.phase !== 'results') return 'NOT_ALLOWED';
	if (by !== s.hostId) return 'NOT_HOST';
	const target = findPlayer(s, playerId);
	if (!target) return 'UNKNOWN_PLAYER';
	if (target.id === by) return 'NOT_ALLOWED';
	s.blockedDevices.push(target.deviceId);
	dropFromRoom(ctx, target, 'removed');
	return undefined;
}

/**
 * Takes a player out of the room entirely (lobby or results), passing on the host role if needed.
 * During a game, players who leave stay on the scoreboard instead (see presence.leaveGame).
 */
export function dropFromRoom(ctx: Ctx, player: Player, reason: 'left' | 'removed'): void {
	const { s } = ctx;
	passHostIfNeeded(ctx, player);
	s.players = s.players.filter((p) => p.id !== player.id);
	emit(ctx, { type: reason === 'removed' ? 'playerRemoved' : 'playerLeft', playerId: player.id });
	if (s.phase === 'results') reopenIfEveryoneBack(ctx);
}

/** R-5: when the host goes, the next player in seat order (still in the game) becomes host. */
export function passHostIfNeeded(ctx: Ctx, leaving: Player): void {
	const { s } = ctx;
	if (s.hostId !== leaving.id) return;
	const candidates = s.players.filter((p) => p.id !== leaving.id && p.status !== 'left');
	const next = orderAfter(candidates, leaving.seat)[0];
	s.hostId = next?.id;
	if (next) emit(ctx, { type: 'hostChanged', playerId: next.id });
}

/** PRD §4.6: once everyone is back, players who left the last game go, and the room reopens. */
export function reopenIfEveryoneBack(ctx: Ctx): void {
	const { s } = ctx;
	if (s.phase !== 'results') return;
	if (!s.players.every((p) => p.returned)) return;
	s.players = bySeat(s.players.filter((p) => p.status !== 'left'));
	for (const p of s.players) {
		p.status = 'active';
		p.roundScore = undefined;
		p.forced = false;
	}
	s.phase = 'lobby';
	s.resultsAt = undefined;
	s.outcome = undefined;
	emit(ctx, { type: 'roomReopened' });
}
