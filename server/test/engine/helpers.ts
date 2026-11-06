/**
 * Test helpers for the rules engine.
 *
 * Conventions: players are `p1`, `p2`, … in seat order, and `p1` is the host. `play()` makes the
 * last player the Dealer by default, so the first deal goes p1, p2, …, pN and the first turn is p1's.
 */
import { buildDeck, type Card } from '../../src/engine/cards';
import { applyAction, createRoom, dueActions, nextRoundWith, startWith, type ApplyResult } from '../../src/engine/engine';
import { getPlayer } from '../../src/engine/players';
import { seededRng, type Rng } from '../../src/engine/rng';
import type { Action, Decision, ErrorCode, GameEvent, GameState, Mode, Player } from '../../src/engine/state';

export const T0 = 1_000_000;
export const NAMES = ['Ali', 'Sara', 'Omar', 'Noura', 'Fahad', 'Reem', 'Khalid', 'Huda'];

/** A card on top of a stacked deck: a number, `+N`, `x2`, `freeze`, `d3` (Draw Three) or `sc` (Second Chance). */
export type Spec = number | '+2' | '+4' | '+6' | '+8' | '+10' | 'x2' | 'freeze' | 'd3' | 'sc';

function matches(card: Card, spec: Spec): boolean {
	if (typeof spec === 'number') return card.kind === 'number' && card.value === spec;
	if (spec === 'x2') return card.kind === 'x2';
	if (spec === 'freeze') return card.kind === 'action' && card.action === 'freeze';
	if (spec === 'd3') return card.kind === 'action' && card.action === 'draw_three';
	if (spec === 'sc') return card.kind === 'action' && card.action === 'second_chance';
	return card.kind === 'plus' && card.amount === Number(spec.slice(1));
}

/** A full 94-card deck with `top` on top, in order. The rest follow in the deck's built order. */
export function stackDeck(top: Spec[], deckNo = 1): Card[] {
	const rest = buildDeck(deckNo);
	const stacked = top.map((spec) => {
		const index = rest.findIndex((card) => matches(card, spec));
		if (index < 0) throw new Error(`no copy of ${spec} left to stack`);
		return rest.splice(index, 1)[0]!;
	});
	return [...stacked, ...rest];
}

export class Game {
	state: GameState;
	now = T0;
	rng: Rng;
	/** Every event so far, in order. */
	log: GameEvent[] = [];

	constructor(state: GameState = createRoom(), seed = 1) {
		this.state = state;
		this.rng = seededRng(seed);
	}

	get env() {
		return { rng: this.rng, now: this.now };
	}

	private apply(result: ApplyResult, label: string): GameEvent[] {
		if (!result.ok) throw new Error(`${label} failed: ${result.error}`);
		this.state = result.state;
		this.log.push(...result.events);
		return result.events;
	}

	/** Applies an action that must succeed, and returns its events. */
	act(action: Action): GameEvent[] {
		return this.apply(applyAction(this.state, action, this.env), action.type);
	}

	/** Applies an action that must fail, and returns its error. The state is unchanged. */
	reject(action: Action): ErrorCode {
		const result = applyAction(this.state, action, this.env);
		if (result.ok) throw new Error(`expected ${action.type} to fail`);
		return result.error;
	}

	start(top: Spec[], dealerId: string): GameEvent[] {
		const deck = stackDeck(top, this.state.nextDeckNo);
		return this.apply(startWith(this.state, this.state.hostId!, this.env, { deck, firstDealerId: dealerId }), 'start');
	}

	/** Waits out the break between rounds and starts the next one. `top` stacks a fresh deck if one is used. */
	nextRound(top?: Spec[], dealerId?: string): GameEvent[] {
		if (this.state.nextRoundAt !== undefined) this.now = Math.max(this.now, this.state.nextRoundAt);
		const deck = top ? stackDeck(top, this.state.nextDeckNo) : undefined;
		return this.apply(nextRoundWith(this.state, this.env, { deck, dealerId }), 'nextRound');
	}

	tick(ms: number): void {
		this.now += ms;
	}

	/** Runs every system action that's due now, like the room's alarm does. */
	runDue(): GameEvent[] {
		const events: GameEvent[] = [];
		for (;;) {
			const next = dueActions(this.state, this.now)[0];
			if (!next) return events;
			events.push(...this.act(next.action));
		}
	}

	get decision(): Decision {
		if (!this.state.decision) throw new Error('no open decision');
		return this.state.decision;
	}

	/** The open decision, which must be a Hit/Stay turn. */
	get turn(): Extract<Decision, { kind: 'hit_or_stay' }> {
		const decision = this.decision;
		if (decision.kind !== 'hit_or_stay') throw new Error(`expected a Hit/Stay turn, got ${decision.kind}`);
		return decision;
	}

	/** The open decision, which must be a choice of target. */
	get choice(): Exclude<Decision, { kind: 'hit_or_stay' }> {
		const decision = this.decision;
		if (decision.kind === 'hit_or_stay') throw new Error('expected a choice of target, got a Hit/Stay turn');
		return decision;
	}

	hit(by = this.decision.playerId): GameEvent[] {
		return this.act({ type: 'hit', by, decisionId: this.decision.id });
	}

	stay(by = this.decision.playerId): GameEvent[] {
		return this.act({ type: 'stay', by, decisionId: this.decision.id });
	}

	choose(targetId: string, by = this.decision.playerId): GameEvent[] {
		return this.act({ type: 'choose', by, decisionId: this.decision.id, targetId });
	}

	player(id: string): Player {
		return getPlayer(this.state, id);
	}

	/** Number values in a player's row, in the order received. */
	row(id: string): number[] {
		return this.player(id).row.map((card) => card.value);
	}

	/** The deck's top card as a short spec, for checking what wasn't drawn. */
	topOfDeck(): string {
		const card = this.state.deck[0];
		if (!card) return '(empty)';
		if (card.kind === 'number') return String(card.value);
		if (card.kind === 'plus') return `+${card.amount}`;
		return card.kind === 'x2' ? 'x2' : card.action;
	}
}

/** A lobby with `count` players (p1 is the host), and optional settings. */
export function lobby(count: number, settings?: { mode?: Mode; targetScore?: number }, seed = 1): Game {
	const game = new Game(createRoom(), seed);
	for (let i = 1; i <= count; i++) {
		game.act({ type: 'join', playerId: `p${i}`, token: `token-p${i}`, deviceId: `device-p${i}`, nickname: NAMES[i - 1]! });
	}
	if (settings) {
		const mode = settings.mode ?? 'normal';
		game.act({ type: 'settings', by: 'p1', mode, targetScore: settings.targetScore ?? (mode === 'hard' ? 400 : 200) });
	}
	return game;
}

/** A started game with `top` stacked on the deck. The Dealer is the last player unless given. */
export function play(count: number, top: Spec[], opts: { mode?: Mode; targetScore?: number; dealer?: string; seed?: number } = {}): Game {
	const game = lobby(count, { mode: opts.mode, targetScore: opts.targetScore }, opts.seed);
	game.start(top, opts.dealer ?? `p${count}`);
	return game;
}

export function types(events: GameEvent[]): string[] {
	return events.map((event) => event.type);
}

export function ofType<T extends GameEvent['type']>(events: GameEvent[], type: T): Extract<GameEvent, { type: T }>[] {
	return events.filter((event): event is Extract<GameEvent, { type: T }> => event.type === type);
}
