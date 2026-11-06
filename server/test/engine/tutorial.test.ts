/** The tutorial game against the bot (PRD §4.9), and the last drawn card in the view (PRD §6.2). */
import { describe, expect, it } from 'vitest';
import { botMove, bustRisk } from '../../src/engine/bot';
import {
	BOT_CHOOSE_MS,
	BOT_HIT_OR_STAY_MS,
	BOT_ID,
	RETURN_MS,
	TUTORIAL_DECISION_MS,
	TUTORIAL_TARGET_SCORE,
} from '../../src/engine/constants';
import { createRoom, nextDeadline, publicView } from '../../src/engine/engine';
import { seededRng } from '../../src/engine/rng';
import { Game, ofType, play } from './helpers';

/** A tutorial room after its one player (p1) joined, which seats the bot and starts the game. */
function tutorial(seed = 1): Game {
	const game = new Game(createRoom({ tutorial: true }), seed);
	game.act({ type: 'join', playerId: 'p1', token: 'token-p1', deviceId: 'device-p1', nickname: 'Ali' });
	return game;
}

/** Plays until the game ends: p1 hits until it has 2 numbers, then stays; the bot moves on its alarm. */
function playOut(game: Game): void {
	for (let step = 0; step < 2000 && game.state.phase !== 'results'; step++) {
		const decision = game.state.decision;
		if (decision?.playerId === 'p1') {
			if (decision.kind === 'hit_or_stay') {
				if (decision.canStay && game.player('p1').row.length >= 2) game.stay();
				else game.hit();
			} else game.choose(decision.targets[0]!);
			continue;
		}
		const at = nextDeadline(game.state);
		if (at === undefined) throw new Error(`stuck in ${game.state.phase}`);
		game.now = Math.max(game.now, at);
		game.runDue();
	}
	expect(game.state.phase).toBe('results');
}

describe('tutorial room (PRD §4.9)', () => {
	it('is Normal Mode to 50 points', () => {
		const state = createRoom({ tutorial: true });
		expect(state.tutorial).toBe(true);
		expect(state.settings).toEqual({ mode: 'normal', targetScore: TUTORIAL_TARGET_SCORE });
		expect(createRoom().tutorial).toBeUndefined();
	});

	it('seats the bot and starts the game as soon as the player joins', () => {
		const game = tutorial();
		const bot = game.player(BOT_ID);
		expect(bot.bot).toBe(true);
		expect(bot.connected).toBe(true);
		expect(game.state.hostId).toBe('p1');
		expect(['dealing', 'turns']).toContain(game.state.phase);
		expect(game.state.roundPlayerIds.sort()).toEqual([BOT_ID, 'p1'].sort());
		expect(game.log.map((e) => e.type)).toContain('gameStarted');
	});

	it('refuses anyone else, settings changes and removals', () => {
		const game = tutorial();
		// The game has started, so a second join is refused like any started game.
		expect(game.reject({ type: 'join', playerId: 'p2', token: 't2', deviceId: 'd2', nickname: 'Sara' })).toBe('GAME_STARTED');
		expect(game.reject({ type: 'settings', by: 'p1', mode: 'hard', targetScore: 400 })).toBe('NOT_ALLOWED');

		const empty = new Game(createRoom({ tutorial: true }));
		empty.state.players.push({ ...game.player('p1') });
		empty.state.phase = 'lobby';
		expect(empty.reject({ type: 'join', playerId: 'p2', token: 't2', deviceId: 'd2', nickname: 'Sara' })).toBe('ROOM_FULL');
	});

	it('gives the player a long timer and the bot a short thinking time', () => {
		const game = tutorial(3);
		for (let i = 0; i < 40 && game.state.phase !== 'results'; i++) {
			const decision = game.state.decision;
			if (!decision) {
				game.now = Math.max(game.now, nextDeadline(game.state)!);
				game.runDue();
				continue;
			}
			if (decision.playerId === 'p1') {
				expect(decision.deadline).toBe(game.now + TUTORIAL_DECISION_MS);
				if (decision.kind === 'hit_or_stay') game.hit();
				else game.choose(decision.targets[0]!);
			} else {
				const ms = decision.kind === 'hit_or_stay' ? BOT_HIT_OR_STAY_MS : BOT_CHOOSE_MS;
				expect(decision.deadline).toBe(game.now + ms);
				game.tick(ms);
				game.runDue();
			}
		}
	});

	it('plays complete games, and the bot never waits on the results screen', () => {
		for (const seed of [1, 2, 3, 4, 5]) {
			const game = tutorial(seed);
			playOut(game);
			expect(game.player(BOT_ID).returned).toBe(true);
			expect(game.player('p1').returned).toBe(false);
			// No 60-second return timer: the tutorial waits for Play again or Home.
			expect(nextDeadline(game.state)).toBeUndefined();
			game.tick(RETURN_MS * 2);
			expect(game.runDue()).toEqual([]);
		}
	});

	it('starts a new game when the player taps Play again (Continue)', () => {
		const game = tutorial(7);
		playOut(game);
		const events = game.act({ type: 'continue', by: 'p1' });
		expect(events.map((e) => e.type)).toEqual(expect.arrayContaining(['roomReopened', 'gameStarted', 'roundStarted']));
		expect(['dealing', 'turns']).toContain(game.state.phase);
		expect(game.state.round).toBe(1);
		for (const p of game.state.players) expect(p.total).toBe(0);
	});

	it('pauses when the player disconnects, so the bot never plays on alone', () => {
		const game = tutorial(2);
		game.act({ type: 'disconnect', playerId: 'p1' });
		expect(game.state.phase).toBe('paused');
		game.act({ type: 'reconnect', playerId: 'p1' });
		expect(['dealing', 'turns']).toContain(game.state.phase);
		const decision = game.state.decision!;
		const expected =
			decision.playerId === 'p1' ? TUTORIAL_DECISION_MS : decision.kind === 'hit_or_stay' ? BOT_HIT_OR_STAY_MS : BOT_CHOOSE_MS;
		expect(decision.deadline).toBe(game.now + expected);
	});

	it('ends with the bot winning if the player quits', () => {
		const game = tutorial(4);
		game.act({ type: 'quit', by: 'p1' });
		expect(game.state.phase).toBe('results');
		expect(game.state.outcome).toMatchObject({ winnerIds: [BOT_ID], draw: false });
	});

	it('marks the room and the bot in the view, with nothing private', () => {
		const view = publicView(tutorial().state);
		expect(view.tutorial).toBe(true);
		expect(view.players.find((p) => p.id === BOT_ID)?.bot).toBe(true);
		expect(view.players.find((p) => p.id === 'p1')?.bot).toBeUndefined();
		expect(JSON.stringify(view)).not.toMatch(/token|device/);
		expect(publicView(createRoom()).tutorial).toBeUndefined();
	});
});

describe('the bot (PRD §4.9)', () => {
	/** A 2-player game where p2 is the bot, with `top` stacked on the deck. p1 deals, so p2 is dealt first and plays first. */
	function withBot(top: Parameters<typeof play>[1]) {
		const game = play(2, top, { dealer: 'p1' });
		game.player('p2').bot = true;
		return game;
	}
	const rng = () => seededRng(1);

	it('hits when it cannot stay', () => {
		const game = withBot([5, 3]);
		const decision = { ...game.turn, canStay: false };
		game.player('p2').total = game.state.settings.targetScore;
		expect(botMove(game.state, decision, rng())).toEqual({ type: 'hit' });
	});

	it('keeps hitting with a weak round, and stays with a strong one', () => {
		const game = withBot([12, 3]);
		expect(game.turn.playerId).toBe('p2');
		// A single 12 is a weak round with little risk.
		expect(botMove(game.state, game.turn, rng())).toEqual({ type: 'hit' });
		// 30 points is always enough.
		game.player('p2').modifiers.push({ id: 'm1', kind: 'plus', amount: 10 }, { id: 'm2', kind: 'plus', amount: 8 });
		expect(botMove(game.state, game.turn, rng())).toEqual({ type: 'stay' });
	});

	it('stays when banking its round reaches the winning score', () => {
		const game = withBot([5, 3]);
		game.player('p2').total = game.state.settings.targetScore - 4;
		expect(botMove(game.state, game.turn, rng())).toEqual({ type: 'stay' });
	});

	it('counts only the cards that can come next', () => {
		const game = withBot([12, 3]);
		const p2 = game.player('p2');
		const risk = bustRisk(game.state, p2);
		const twelvesLeft = game.state.deck.filter((c) => c.kind === 'number' && c.value === 12).length;
		expect(risk).toBeCloseTo(twelvesLeft / game.state.deck.length);
		p2.secondChance = { id: 'sc', kind: 'action', action: 'second_chance' };
		expect(bustRisk(game.state, p2)).toBeCloseTo(risk * 0.2);
	});

	it('gives Flip Three to the opponent, and freezes the leader unless it should bank', () => {
		const flip = withBot(['f3']);
		expect(flip.choice.playerId).toBe('p2');
		expect(botMove(flip.state, flip.choice, rng())).toEqual({ type: 'choose', targetId: 'p1' });

		const freeze = withBot(['freeze']);
		expect(botMove(freeze.state, freeze.choice, rng())).toEqual({ type: 'choose', targetId: 'p1' });
		// With a good round and a risky deck, it freezes itself to bank.
		const p2 = freeze.player('p2');
		p2.row = [12, 11, 10].map((value, i) => ({ id: `r${i}`, kind: 'number' as const, value }));
		freeze.state.deck = freeze.state.deck.filter((c) => c.kind === 'number' && c.value >= 10);
		expect(botMove(freeze.state, freeze.choice, rng())).toEqual({ type: 'choose', targetId: 'p2' });
	});

	it('moves on its own when its thinking time runs out', () => {
		const game = withBot([12, 3]);
		expect(game.turn.playerId).toBe('p2');
		game.now = game.turn.deadline;
		const events = game.runDue();
		expect(events.some((e) => e.type === 'cardDealt' || e.type === 'stayed')).toBe(true);
		expect(events.some((e) => e.type === 'autoHit' || e.type === 'autoStayed')).toBe(false);
	});
});

describe('last drawn card (PRD §6.2)', () => {
	it('follows every card revealed, with who got it and how', () => {
		const game = play(2, [3, 5, 8]);
		expect(publicView(game.state).lastDraw).toMatchObject({ playerId: 'p2', source: 'deal', card: { kind: 'number', value: 5 } });
		game.hit();
		expect(publicView(game.state).lastDraw).toMatchObject({ playerId: 'p1', source: 'hit', card: { kind: 'number', value: 8 } });
	});

	it('stays through the break between rounds and is replaced by the next deal', () => {
		const game = play(2, [3, 5, 3]);
		game.hit(); // p1 busts on the second 3; p2 is alone and plays on
		while (game.state.phase !== 'round_over') game.stay();
		const last = game.state.lastDraw;
		expect(last).toBeDefined();
		expect(publicView(game.state).lastDraw).toEqual(last);
		game.nextRound();
		expect(game.state.lastDraw?.source).toBe('deal');
		expect(game.state.lastDraw?.card.id).not.toBe(last!.card.id);
	});
});
