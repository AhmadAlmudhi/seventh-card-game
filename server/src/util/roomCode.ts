/** Room codes (PRD R-1): 5 characters, leaving out look-alikes (0/O, 1/I/L). About 28 million codes. */
import { cryptoRng, type Rng } from '../engine/rng';

export const ROOM_CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
export const ROOM_CODE_LENGTH = 5;

const PATTERN = new RegExp(`^[${ROOM_CODE_ALPHABET}]{${ROOM_CODE_LENGTH}}$`);

export function generateRoomCode(rng: Rng = cryptoRng()): string {
	let code = '';
	for (let i = 0; i < ROOM_CODE_LENGTH; i++) code += ROOM_CODE_ALPHABET[rng.int(ROOM_CODE_ALPHABET.length)];
	return code;
}

/** True for a well-formed code. Codes are upper case; the app upper-cases what the player types. */
export function isRoomCode(value: string): boolean {
	return PATTERN.test(value);
}
