/**
 * Simulation tests (PRD §11.2). Bots play complete random games, including disconnects, quits and
 * timeouts, and the invariants are checked after every action.
 *
 *   SIM_GAMES=10000 npm run test:sim    more games (nightly / before a release)
 *   SIM_SEED=1234 npm run test:sim      replay one failing game
 */
import { describe, expect, it } from 'vitest';
import { DECK_SIZE, type Card } from '../../src/engine/cards';
import {
	applyAction,
	createRoom,
	dueActions,
	nextDeadline,
	publicView,
	type Action,
	type GameEvent,
	type GameState,
} from '../../src/engine/engine';
import { seededRng, type Rng } from '../../src/engine/rng';
import { NAMES } from './helpers';

const GAMES = Number(process.env.SIM_GAMES ?? 1000);
const ONLY_SEED = process.env.SIM_SEED ? Number(process.env.SIM_SEED) : undefined;
const MAX_STEPS = 20_000;

describe('simulation', () => {
	it(`plays ${ONLY_SEED !== undefined ? `seed ${ONLY_SEED}` : `${GAMES} random games`} with every invariant holding`, () => {
		const seeds = ONLY_SEED !== undefined ? [ONLY_SEED] : Array.from({ length: GAMES }, (_, i) => i + 1);
		const totals = { games: 0, actions: 0, rounds: 0, tiebreaks: 0, abandoned: 0, secondDecks: 0, sevenths: 0, busts: 0 };
		const slowest = { seed: 0, ms: 0, actions: 0 };
		for (const seed of seeds) {
			try {
				const started = performance.now();
				const stats = simulate(seed);
				const ms = performance.now() - started;
				if (ms > slowest.ms) Object.assign(slowest, { seed, ms: Math.round(ms), actions: stats.actions });
				totals.games += 1;
				totals.actions += stats.actions;
				totals.rounds += stats.rounds;
				totals.tiebreaks += stats.tiebreaks;
				totals.abandoned += stats.abandoned ? 1 : 0;
				totals.secondDecks += stats.secondDecks;
				totals.sevenths += stats.sevenths;
				totals.busts += stats.busts;
			} catch (error) {
				throw new Error(`simulation failed on seed ${seed} (replay with SIM_SEED=${seed}): ${(error as Error).message}`, { cause: error });
			}
		}
		console.log('simulation totals', totals, 'slowest game', slowest);
		expect(totals.games).toBe(seeds.length);
	}, 600_000);
});

interface Stats {
	actions: number;
	rounds: number;
	tiebreaks: number;
	abandoned: boolean;
	secondDecks: number;
	sevenths: number;
	busts: number;
}

function simulate(seed: number): Stats {
	const bot = seededRng(seed);
	const engineRng = seededRng(seed * 7919 + 1);
	let now = 1_000_000;
	let state = createRoom();
	const stats: Stats = { actions: 0, rounds: 0, tiebreaks: 0, abandoned: false, secondDecks: 0, sevenths: 0, busts: 0 };

	const apply = (action: Action): boolean => {
		const result = applyAction(state, action, { rng: engineRng, now });
		if (!result.ok) return false;
		const before = state;
		state = result.state;
		stats.actions += 1;
		for (const event of result.events) {
			if (event.type === 'roundStarted') stats.rounds += 1;
			if (event.type === 'tiebreakStarted') stats.tiebreaks += 1;
			if (event.type === 'extraDeckAdded') stats.secondDecks += 1;
			if (event.type === 'seventhCard') stats.sevenths += 1;
			if (event.type === 'busted') stats.busts += 1;
		}
		checkInvariants(before, state, result.events);
		return true;
	};

	const count = 2 + bot.int(7);
	for (let i = 0; i < count; i++) {
		must(apply({ type: 'join', playerId: `p${i + 1}`, token: `token-${i}`, deviceId: `device-${i}`, nickname: NAMES[i]! }), 'join');
	}
	const mode = bot.int(2) === 0 ? 'normal' : 'hard';
	must(apply({ type: 'settings', by: 'p1', mode, targetScore: 100 + 50 * bot.int(5) }), 'settings');
	must(apply({ type: 'start', by: 'p1' }), 'start');

	for (let step = 0; step < MAX_STEPS; step++) {
		if (state.phase === 'results' || state.phase === 'abandoned') {
			stats.abandoned = state.phase === 'abandoned';
			return stats;
		}
		const roll = bot.int(1000);
		const inGame = state.players.filter((p) => p.status !== 'left');
		if (roll < 4) {
			const target = randomOf(
				inGame.filter((p) => p.connected),
				bot,
			);
			if (target) apply({ type: 'disconnect', playerId: target.id });
			continue;
		}
		if (roll < 10) {
			const target = randomOf(
				inGame.filter((p) => !p.connected),
				bot,
			);
			if (target) apply({ type: 'reconnect', playerId: target.id });
			continue;
		}
		if (roll < 11) {
			const target = randomOf(inGame, bot);
			if (target) apply({ type: 'quit', by: target.id });
			continue;
		}

		const decision = state.decision;
		if (decision && (state.phase === 'dealing' || state.phase === 'turns')) {
			const owner = state.players.find((p) => p.id === decision.playerId)!;
			if (!owner.connected || bot.int(20) === 0) {
				now = Math.max(now, decision.deadline);
				must(apply({ type: 'timeout', decisionId: decision.id }), 'timeout');
			} else if (decision.kind === 'hit_or_stay') {
				const stay = decision.canStay && bot.int(3) === 0;
				must(apply({ type: stay ? 'stay' : 'hit', by: owner.id, decisionId: decision.id }), 'hit/stay');
			} else {
				must(apply({ type: 'choose', by: owner.id, decisionId: decision.id, targetId: randomOf(decision.targets, bot)! }), 'choose');
			}
			continue;
		}

		// Nothing to answer: jump to the next scheduled event, like the room's alarm.
		const at = nextDeadline(state);
		if (at === undefined) throw new Error(`stuck in phase ${state.phase}: no decision and nothing scheduled`);
		now = Math.max(now, at);
		const due = scheduledAction(state, now);
		must(apply(due), `system action ${due.type}`);
	}
	throw new Error(`game didn't finish within ${MAX_STEPS} actions (phase ${state.phase}, round ${state.round})`);
}

function scheduledAction(state: GameState, now: number): Action {
	const next = dueActions(state, now)[0];
	if (!next) throw new Error('nextDeadline promised something due, but nothing was');
	return next.action;
}

function must(ok: boolean, what: string): void {
	if (!ok) throw new Error(`${what} was refused`);
}

function randomOf<T>(items: readonly T[], rng: Rng): T | undefined {
	return items.length === 0 ? undefined : items[rng.int(items.length)];
}

// ---------------------------------------------------------------------------
// Invariants (PRD §11.2)
// ---------------------------------------------------------------------------

function cardsInPlay(s: GameState): Card[] {
	const cards: Card[] = [...s.deck, ...s.discard];
	for (const p of s.players) {
		cards.push(...p.row, ...p.modifiers, ...p.played);
		if (p.secondChance) cards.push(p.secondChance);
		if (p.bustCard) cards.push(p.bustCard);
	}
	if (s.decision && s.decision.kind !== 'hit_or_stay') cards.push(s.decision.card);
	return cards;
}

/** An independent implementation of the scoring rules (Rules §8, §11). */
function expectedRoundScore(p: GameState['players'][number], mode: 'normal' | 'hard'): number {
	if (p.status === 'left') return 0;
	if (p.status === 'busted') return mode === 'hard' ? -5 : 0;
	let total = 0;
	for (const card of p.row) total += card.value;
	for (const card of p.modifiers) if (card.kind === 'x2') total *= 2;
	for (const card of p.modifiers) if (card.kind === 'plus') total += card.amount;
	return total + (p.seventhCard ? 15 : 0);
}

function checkInvariants(before: GameState, s: GameState, events: GameEvent[]): void {
	// Every card is accounted for, exactly once. (In the lobby after a game, players who left take their table cards with them.)
	if (s.phase !== 'lobby') {
		const cards = cardsInPlay(s);
		if (cards.length !== DECK_SIZE * s.decksInPlay) {
			throw new Error(`card count ${cards.length}, expected ${DECK_SIZE * s.decksInPlay}`);
		}
		if (new Set(cards.map((c) => c.id)).size !== cards.length) throw new Error('a card is in two places at once');
	}

	for (const p of s.players) {
		// No row ever holds the same number twice (a duplicate either busts or is saved and discarded).
		const values = p.row.map((c) => c.value);
		if (new Set(values).size !== values.length) throw new Error(`${p.id} has a duplicate number in their row`);
		if (p.secondChance && !(p.secondChance.kind === 'action' && p.secondChance.action === 'second_chance')) {
			throw new Error(`${p.id} holds a non-Second Chance card as their Second Chance`);
		}
		if (p.seventhCard && p.row.length !== 7) throw new Error(`${p.id} has the Seventh Card with ${p.row.length} numbers`);
	}

	const d = s.decision;
	if (d) {
		const owner = s.players.find((p) => p.id === d.playerId);
		if (!owner) throw new Error('decision for a player who is gone');
		if (d.kind === 'hit_or_stay') {
			if (owner.status !== 'active') throw new Error('Hit/Stay offered to an inactive player');
			if (d.canStay !== owner.row.length >= 1) throw new Error('canStay disagrees with the number cards held');
			if (owner.forced && owner.row.length <= 3) throw new Error('a forced player with ≤3 numbers got a Hit/Stay prompt');
		} else {
			for (const id of d.targets) {
				const target = s.players.find((p) => p.id === id);
				if (!target || target.status !== 'active') throw new Error(`inactive target ${id}`);
				if (d.kind === 'give_second_chance' && (target.secondChance || id === d.playerId))
					throw new Error(`ineligible Second Chance target ${id}`);
			}
		}
	}

	for (const event of events) {
		// A forced player never stays with 3 or fewer number cards.
		if (event.type === 'stayed' || event.type === 'autoStayed') {
			const p = s.players.find((x) => x.id === event.playerId)!;
			if (p.forced && p.row.length <= 3) throw new Error(`forced player ${p.id} stayed with ${p.row.length} numbers`);
		}
		// Round scores match the independent scoring function. Hands stay on the table until the next round starts.
		if (event.type === 'roundScored') {
			for (const score of event.scores) {
				const p = s.players.find((x) => x.id === score.playerId)!;
				const expected = expectedRoundScore(p, s.settings.mode);
				if (score.roundScore !== expected) throw new Error(`${p.id} scored ${score.roundScore}, expected ${expected}`);
			}
		}
		if (event.type === 'tiebreakStarted' && event.roundNo > 3) throw new Error(`tie-break round ${event.roundNo}`);
		if (event.type === 'gameOver') {
			for (const id of event.winnerIds) {
				if (s.players.find((p) => p.id === id)?.status === 'left') throw new Error('a player who left won');
			}
		}
	}

	// Totals only change when a round is scored.
	if (!events.some((e) => e.type === 'roundScored' || e.type === 'gameStarted')) {
		for (const p of s.players) {
			const old = before.players.find((x) => x.id === p.id);
			if (old && old.total !== p.total) throw new Error(`${p.id}'s total changed mid-round`);
		}
	}

	// The view never contains the deck order or private fields.
	const json = JSON.stringify(publicView(s));
	const idsInView = new Set(json.match(/"d\d+-\d+"/g)?.map((quoted) => quoted.slice(1, -1)));
	for (const card of s.deck) if (idsInView.has(card.id)) throw new Error(`deck card ${card.id} leaked into the view`);
	if (/token-|device-/.test(json)) throw new Error('a token or device id leaked into the view');
}
