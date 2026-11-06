/** Nickname rules (PRD §4.1, R-4). */
import { NICKNAME_MAX_LENGTH } from './constants';

/** Arabic and Latin letters, their combining marks, digits, spaces and the Arabic tatweel. */
const ALLOWED = /^[\p{Script=Arabic}\p{Script=Latin}\p{M}\p{Nd}ـ ]+$/u;

/**
 * Returns the cleaned nickname, or null if it isn't allowed. Cleaning means Unicode NFC,
 * trimming, and collapsing runs of whitespace into one space.
 */
export function normalizeNickname(raw: string): string | null {
	const nickname = raw.normalize('NFC').replace(/\s+/gu, ' ').trim();
	const length = [...nickname].length;
	if (length < 1 || length > NICKNAME_MAX_LENGTH) return null;
	if (!ALLOWED.test(nickname)) return null;
	return nickname;
}

/** Two nicknames clash when these keys match: NFC, ignoring Latin upper/lower case. */
export function nicknameKey(nickname: string): string {
	return nickname.normalize('NFC').toLowerCase();
}
