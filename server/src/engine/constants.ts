/** Game constants. Rule references are to game_rules.md. */

/** Rules §12.1 */
export const MIN_PLAYERS = 2;
export const MAX_PLAYERS = 8;

/** Rules §2, §8: seven different number cards end the round and score a bonus. */
export const SEVENTH_CARD_COUNT = 7;
export const SEVENTH_CARD_BONUS = 15;

/** Rules §11 */
export const HARD_MODE_BUST_SCORE = -5;
export const FORCED_LINE_RATIO = 0.75;
export const FORCED_MAX_NUMBER_CARDS = 3;

/** Rules §1, §12.8 */
export const DEFAULT_TARGET_SCORE = { normal: 200, hard: 400 } as const;
export const TARGET_SCORE_MIN = 100;
export const TARGET_SCORE_MAX = 1000;
export const TARGET_SCORE_STEP = 50;

/** Rules §10.2 */
export const MAX_TIEBREAK_ROUNDS = 3;

/** Rules §12.2–12.5 and PRD §4.6 */
export const HIT_OR_STAY_MS = 15_000;
export const CHOOSE_MS = 10_000;
export const GRACE_MS = 120_000;
export const PAUSE_MS = 300_000;
export const RETURN_MS = 60_000;

/**
 * Pause between rounds, so every player sees the round scores before the next deal and the
 * first decision timer of the next round doesn't start while round-end animations are playing.
 */
export const ROUND_BREAK_MS = 4_000;

/** PRD §4.1 */
export const NICKNAME_MAX_LENGTH = 16;
