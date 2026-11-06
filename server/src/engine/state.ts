/** Engine types (PRD §8.4). */
import type { ActionCard, Card, ModifierCard, NumberCard } from './cards';
import type { Rng } from './rng';

export type Mode = 'normal' | 'hard';

export interface Settings {
	mode: Mode;
	targetScore: number;
}

/**
 * - `lobby`: open to joins; the host can change settings and start.
 * - `dealing` / `turns`: a round is being played.
 * - `round_over`: the short break between rounds (`nextRoundAt`).
 * - `results`: the game is over; waiting for everyone to tap Continue (PRD §4.6).
 * - `paused`: every player disconnected mid-game (Rules §12.5).
 * - `abandoned`: the pause ran out; the game ended with no result.
 */
export type Phase = 'lobby' | 'dealing' | 'turns' | 'round_over' | 'results' | 'paused' | 'abandoned';

/**
 * Status for the current round. `watching` is a player sitting out a tie-break round (Rules §10.2).
 * `left` lasts for the rest of the game (Rules §12.4).
 */
export type PlayerStatus = 'active' | 'stayed' | 'frozen' | 'busted' | 'left' | 'watching';

export interface Player {
	id: string;
	nickname: string;
	/** Seat order: the order players joined, made contiguous when a game starts. */
	seat: number;
	/** Private: never sent in the view. */
	token: string;
	/** Private: never sent in the view. */
	deviceId: string;
	total: number;
	connected: boolean;
	disconnectedAt?: number;
	status: PlayerStatus;
	row: NumberCard[];
	modifiers: ModifierCard[];
	secondChance?: ActionCard;
	/** Freeze and Flip Three cards this player revealed, kept on the table until the round ends. */
	played: ActionCard[];
	/** The duplicate number that busted this player, kept on the table until the round ends. */
	bustCard?: NumberCard;
	seventhCard: boolean;
	/** Hard Mode: at or above the forced-Hit line when the round started (Rules §11.1). */
	forced: boolean;
	/** Set when the round is scored; cleared when the next round starts. */
	roundScore?: number;
	/** Back in the room after the results screen (PRD §4.6). */
	returned: boolean;
	/** The tutorial's computer player (PRD §4.9). Always connected; the engine makes its moves. */
	bot?: boolean;
}

/** The card revealed most recently, shown in the middle of the table (PRD §6.2). Public: it was revealed face up. */
export interface LastDraw {
	card: Card;
	playerId: string;
	source: CardSource;
}

export type Task =
	/** Players still due their first card, in order. */
	| { t: 'deal'; queue: string[] }
	/** The normal Hit/Stay loop. */
	| { t: 'turns' }
	| { t: 'flipThree'; playerId: string; remaining: number };

export type Decision =
	| { id: string; kind: 'hit_or_stay'; playerId: string; canStay: boolean; deadline: number }
	| { id: string; kind: 'choose_target'; playerId: string; card: ActionCard; targets: string[]; deadline: number }
	| { id: string; kind: 'give_second_chance'; playerId: string; card: ActionCard; targets: string[]; deadline: number };

export interface Tiebreak {
	roundNo: number;
	playerIds: string[];
}

export interface Outcome {
	winnerIds: string[];
	draw: boolean;
	/** Everyone who played this game, so the results leave out anyone who joined the room afterwards. */
	playerIds: string[];
}

export interface GameState {
	phase: Phase;
	settings: Settings;
	/** A tutorial room (PRD §4.9): one player against the bot, to a fixed winning score. */
	tutorial?: boolean;
	players: Player[];
	hostId?: string;
	/** Device ids of players the host removed (PRD §8.5). Never sent in the view. */
	blockedDevices: string[];

	round: number;
	/** Players dealt into the current round, in seat order. */
	roundPlayerIds: string[];
	dealerId?: string;
	turnPlayerId?: string;
	tiebreak?: Tiebreak;
	/** Top of the deck is index 0. The order is never sent in the view. */
	deck: Card[];
	discard: Card[];
	/** 1, or more after a second deck joined mid-round (Rules §9.2). */
	decksInPlay: number;
	/** Deck number for the next deck built, so card ids never repeat in a room. */
	nextDeckNo: number;
	/** Work left to do this round. The last item is the top of the stack. */
	tasks: Task[];
	decision?: Decision;
	/** Cleared when a round starts, so it's always a card from the current round. */
	lastDraw?: LastDraw;
	/** Decision ids never repeat in a room, so an old answer can never match a new decision. */
	nextDecisionNo: number;

	nextRoundAt?: number;
	/** Set while a scored tie-break round is on screen (its number), so the app knows totals didn't change. */
	scoredTiebreakRound?: number;
	resultsAt?: number;
	pausedAt?: number;
	pausedFrom?: Phase;
	outcome?: Outcome;

	/** Bumped by the room on every saved change (PRD §8.3). The engine doesn't touch it. */
	version: number;
}

export type PlayerAction =
	| { type: 'join'; playerId: string; token: string; deviceId: string; nickname: string }
	| { type: 'settings'; by: string; mode: Mode; targetScore: number }
	| { type: 'start'; by: string }
	| { type: 'hit'; by: string; decisionId: string }
	| { type: 'stay'; by: string; decisionId: string }
	| { type: 'choose'; by: string; decisionId: string; targetId: string }
	| { type: 'continue'; by: string }
	| { type: 'remove'; by: string; playerId: string }
	| { type: 'quit'; by: string };

/** Sent by the room, not by players (PRD §8.4). */
export type SystemAction =
	| { type: 'timeout'; decisionId: string }
	| { type: 'disconnect'; playerId: string }
	| { type: 'reconnect'; playerId: string }
	| { type: 'graceExpired'; playerId: string }
	| { type: 'pauseExpired' }
	| { type: 'returnTimeout' }
	| { type: 'nextRound' };

export type Action = PlayerAction | SystemAction;

export type ErrorCode =
	| 'ROOM_FULL'
	| 'GAME_STARTED'
	| 'ROOM_BUSY'
	| 'NICKNAME_TAKEN'
	| 'INVALID_NICKNAME'
	| 'REMOVED'
	| 'NOT_HOST'
	| 'NOT_ALLOWED'
	| 'INVALID_SETTINGS'
	| 'NOT_ENOUGH_PLAYERS'
	| 'STALE'
	| 'INVALID_TARGET'
	| 'CANNOT_STAY'
	| 'UNKNOWN_PLAYER'
	| 'TOO_EARLY';

export type CardSource = 'deal' | 'hit' | 'flipThree';

export interface RoundScore {
	playerId: string;
	roundScore: number;
	total: number;
}

/** Events drive the app's animations, one at a time (PRD §6.3, §9.3). */
export type GameEvent =
	| { type: 'playerJoined'; playerId: string }
	| { type: 'playerLeft'; playerId: string }
	| { type: 'playerRemoved'; playerId: string }
	| { type: 'hostChanged'; playerId: string }
	| { type: 'settingsChanged'; settings: Settings }
	| { type: 'gameStarted' }
	| { type: 'roundStarted'; round: number; dealerId: string; playerIds: string[]; tiebreak?: Tiebreak }
	| { type: 'deckReset' }
	| { type: 'cardDealt'; to: string; card: Card; source: CardSource }
	| { type: 'turnStarted'; playerId: string; forced: boolean }
	| { type: 'decisionRequested'; decision: Decision }
	| { type: 'actionPlayed'; by: string; target: string; card: ActionCard }
	| { type: 'secondChanceKept'; playerId: string; card: ActionCard }
	| { type: 'secondChanceGiven'; by: string; to: string; card: ActionCard }
	| { type: 'secondChanceDiscarded'; by: string; card: ActionCard }
	| { type: 'secondChanceUsed'; playerId: string; card: ActionCard; duplicate: NumberCard }
	| { type: 'frozen'; playerId: string; by: string }
	| { type: 'flipThreeStarted'; playerId: string; by: string; remaining: number }
	| { type: 'flipThreeEnded'; playerId: string; reason: 'done' | 'busted' | 'frozen' | 'left' }
	| { type: 'stayed'; playerId: string }
	| { type: 'autoStayed'; playerId: string }
	| { type: 'autoHit'; playerId: string }
	| { type: 'busted'; playerId: string; duplicate: NumberCard }
	| { type: 'seventhCard'; playerId: string }
	| { type: 'reshuffled'; count: number }
	| { type: 'extraDeckAdded'; deckNo: number }
	| { type: 'roundScored'; scores: RoundScore[] }
	| { type: 'tiebreakStarted'; playerIds: string[]; roundNo: number }
	| { type: 'gameOver'; winnerIds: string[]; draw: boolean }
	| { type: 'playerDisconnected'; playerId: string }
	| { type: 'playerReconnected'; playerId: string }
	| { type: 'gamePaused' }
	| { type: 'gameResumed' }
	| { type: 'gameAbandoned' }
	| { type: 'playerReturned'; playerId: string }
	| { type: 'roomReopened' };

export interface EngineEnv {
	rng: Rng;
	/** Current time in ms. Deadlines are computed from it. */
	now: number;
}

/** Working context for one `applyAction` call: a private copy of the state plus the events so far. */
export interface Ctx {
	s: GameState;
	env: EngineEnv;
	events: GameEvent[];
}

export function emit(ctx: Ctx, event: GameEvent): void {
	ctx.events.push(event);
}
