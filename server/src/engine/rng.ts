/**
 * Randomness is passed into the engine. Production uses crypto randomness; tests use a seeded
 * generator, so any game can be replayed exactly from its seed (PRD §8.4).
 */
export interface Rng {
	/** A uniformly random integer in [0, n). */
	int(n: number): number;
}

/** Unbiased crypto randomness (rejection sampling over 32-bit values). */
export function cryptoRng(): Rng {
	const buffer = new Uint32Array(1);
	return {
		int(n) {
			if (!Number.isInteger(n) || n <= 0 || n > 2 ** 32) throw new RangeError(`bad range ${n}`);
			const limit = 2 ** 32 - (2 ** 32 % n);
			let value: number;
			do {
				crypto.getRandomValues(buffer);
				value = buffer[0]!;
			} while (value >= limit);
			return value % n;
		},
	};
}

/** Deterministic randomness for tests (mulberry32). Not for production. */
export function seededRng(seed: number): Rng {
	let a = seed >>> 0;
	const next = () => {
		a = (a + 0x6d2b79f5) >>> 0;
		let t = a;
		t = Math.imul(t ^ (t >>> 15), t | 1);
		t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
		return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
	};
	return {
		int(n) {
			if (!Number.isInteger(n) || n <= 0) throw new RangeError(`bad range ${n}`);
			return Math.floor(next() * n);
		},
	};
}

/** Fisher–Yates shuffle, in place. Returns the same array. */
export function shuffle<T>(items: T[], rng: Rng): T[] {
	for (let i = items.length - 1; i > 0; i--) {
		const j = rng.int(i + 1);
		[items[i], items[j]] = [items[j]!, items[i]!];
	}
	return items;
}

export function pick<T>(items: readonly T[], rng: Rng): T {
	if (items.length === 0) throw new RangeError('cannot pick from an empty list');
	return items[rng.int(items.length)]!;
}
