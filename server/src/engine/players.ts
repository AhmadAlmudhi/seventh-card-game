/** Helpers for finding players and walking seat order. */
import type { GameState, Player } from './state';

export function findPlayer(s: GameState, id: string): Player | undefined {
	return s.players.find((p) => p.id === id);
}

/** For ids the engine itself put in the state. A miss is a bug, so it throws. */
export function getPlayer(s: GameState, id: string): Player {
	const player = findPlayer(s, id);
	if (!player) throw new Error(`unknown player ${id}`);
	return player;
}

export function bySeat(players: readonly Player[]): Player[] {
	return [...players].sort((a, b) => a.seat - b.seat);
}

/** Players in seat order, starting after `seat` and wrapping around. A player at `seat` comes last. */
export function orderAfter(players: readonly Player[], seat: number): Player[] {
	const sorted = bySeat(players);
	return [...sorted.filter((p) => p.seat > seat), ...sorted.filter((p) => p.seat <= seat)];
}

export function isActive(p: Player): boolean {
	return p.status === 'active';
}

/** Players who are still in the game (they haven't left). Only they can win (Rules §12.4). */
export function remainingPlayers(s: GameState): Player[] {
	return bySeat(s.players.filter((p) => p.status !== 'left'));
}

export function activeIds(s: GameState): string[] {
	return bySeat(s.players.filter(isActive)).map((p) => p.id);
}
