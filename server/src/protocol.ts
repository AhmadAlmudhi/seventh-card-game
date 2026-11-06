/** Messages between the app and a room, as JSON over WebSocket (PRD §8.5). */
import { z } from 'zod';
import type { ErrorCode, GameEvent, PublicView } from './engine/engine';

/** Messages larger than this are refused (PRD §8.5). */
export const MAX_MESSAGE_BYTES = 2048;
/** Messages allowed per connection per second; extra ones are dropped (PRD §8.5). */
export const MAX_MESSAGES_PER_SECOND = 10;
/** Dropped messages a connection may cause before it's closed. */
export const MAX_RATE_STRIKES = 30;

const id = z.string().min(1).max(64);

/** Validates every message from the app. Unknown types and malformed fields are refused. */
export const ClientMessage = z.discriminatedUnion('type', [
	z.object({
		type: z.literal('hello'),
		nickname: z.string().max(200),
		token: z
			.string()
			.regex(/^[0-9a-f]{32}$/)
			.optional(),
		deviceId: z.string().regex(/^[A-Za-z0-9_-]{16,64}$/),
	}),
	z.object({ type: z.literal('settings'), mode: z.enum(['normal', 'hard']), targetScore: z.number().int() }),
	z.object({ type: z.literal('start') }),
	z.object({ type: z.literal('hit'), decisionId: id }),
	z.object({ type: z.literal('stay'), decisionId: id }),
	z.object({ type: z.literal('choose'), decisionId: id, targetId: id }),
	z.object({ type: z.literal('continue') }),
	z.object({ type: z.literal('remove'), playerId: id }),
	z.object({ type: z.literal('quit') }),
]);
export type ClientMessage = z.infer<typeof ClientMessage>;

/**
 * Error codes the app can receive. The app shows each one in the player's language; the server
 * never sends display text (PRD §6.6).
 *
 * Beyond the engine's codes:
 * - `ROOM_NOT_FOUND`: no room has this code.
 * - `SEAT_LOST`: this player was removed from the game after their grace period ran out, or quit.
 * - `NOT_JOINED`: a game message arrived before `hello`.
 * - `INVALID_MESSAGE`: the message wasn't valid JSON, or didn't match the protocol.
 * - `RATE_LIMITED`: too many messages; the connection is being closed.
 * - `INTERNAL`: something went wrong on the server; the state is unchanged.
 */
export type ServerErrorCode = ErrorCode | 'ROOM_NOT_FOUND' | 'SEAT_LOST' | 'NOT_JOINED' | 'INVALID_MESSAGE' | 'RATE_LIMITED' | 'INTERNAL';

export type ServerMessage =
	| { type: 'welcome'; playerId: string; token: string; roomCode: string }
	| { type: 'update'; version: number; events: GameEvent[]; view: PublicView }
	| { type: 'error'; code: ServerErrorCode };

/**
 * Close codes for connections the server ends. The `error` message sent just before carries the
 * reason; these let the app tell a deliberate close from a dropped connection, so it doesn't retry.
 */
export const CloseCode = {
	/** Normal close after Quit. */
	QUIT: 1000,
	/** The join or reconnect was refused (see the error just sent). Don't retry. */
	REFUSED: 4000,
	/** The same player connected again from somewhere else. Don't retry. */
	REPLACED: 4001,
	/** The room was closed or deleted. Don't retry. */
	ROOM_CLOSED: 4002,
	/** Too many messages. */
	RATE_LIMITED: 4003,
} as const;
