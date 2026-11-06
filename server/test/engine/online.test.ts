import { describe, expect, it } from 'vitest';
import { applyAction, dueActions, nextDeadline } from '../../src/engine/engine';
import { seededRng } from '../../src/engine/rng';
import { lobby, ofType, play, types } from './helpers';

describe('timers (Rules §12.2)', () => {
	it('gives 15 s for Hit or Stay and 10 s for choosing a target', () => {
		const game = play(2, [3, 4, 'freeze']);
		expect(game.decision.deadline).toBe(game.now + 15_000);
		game.hit();
		expect(game.decision).toMatchObject({ kind: 'choose_target', deadline: game.now + 10_000 });
	});

	it('a connected player who times out always stays', () => {
		const game = play(2, [5, 6, 7]);
		game.tick(15_000);
		for (let seed = 1; seed <= 20; seed++) {
			const result = applyAction(game.state, { type: 'timeout', decisionId: game.decision.id }, { rng: seededRng(seed), now: game.now });
			if (!result.ok) throw new Error(result.error);
			expect(types(result.events)).toContain('autoStayed');
			expect(types(result.events)).not.toContain('autoHit');
		}
	});

	it('when Stay isn’t allowed, a timeout always hits', () => {
		const game = play(2, ['+4', 6, 7]);
		game.tick(15_000);
		const events = game.runDue();
		expect(types(events)).toContain('autoHit');
		expect(game.row('p1')).toEqual([7]);
	});

	it('gives a Freeze or Draw Three to the Drawer when they run out of time', () => {
		for (const card of ['freeze', 'd3'] as const) {
			const game = play(2, [3, 4, card]);
			game.hit();
			game.tick(10_000);
			const events = game.runDue();
			expect(ofType(events, 'actionPlayed')[0]).toMatchObject({ by: 'p1', target: 'p1' });
		}
	});

	it('…also when the Drawer is disconnected', () => {
		const game = play(3, [3, 4, 5, 'freeze']);
		game.hit();
		game.act({ type: 'disconnect', playerId: 'p1' });
		game.tick(10_000);
		expect(ofType(game.runDue(), 'frozen')[0]).toMatchObject({ playerId: 'p1', by: 'p1' });
	});

	it('gives an extra Second Chance to a random eligible player, since the Drawer can’t keep it', () => {
		const game = play(3, ['sc', 4, 5, 'sc']);
		game.hit();
		expect(game.choice.kind).toBe('give_second_chance');
		game.tick(10_000);
		const given = ofType(game.runDue(), 'secondChanceGiven')[0]!;
		expect(['p2', 'p3']).toContain(given.to);
	});

	it('refuses a timeout before the deadline', () => {
		const game = play(2, [5, 6]);
		game.tick(14_999);
		expect(game.reject({ type: 'timeout', decisionId: game.decision.id })).toBe('TOO_EARLY');
		expect(dueActions(game.state, game.now)).toEqual([]);
		expect(nextDeadline(game.state)).toBe(game.now + 1);
	});
});

describe('duplicate moves (PRD §8.6)', () => {
	it('a decision id only works once', () => {
		const game = play(2, [5, 6, 7]);
		const first = game.decision.id;
		game.hit();
		expect(game.reject({ type: 'hit', by: 'p1', decisionId: first })).toBe('STALE');
		expect(game.reject({ type: 'stay', by: 'p1', decisionId: first })).toBe('STALE');
	});

	it('an unrelated change, like another player disconnecting, doesn’t make a valid move stale', () => {
		const game = play(3, [5, 6, 7, 8]);
		const id = game.decision.id;
		game.act({ type: 'disconnect', playerId: 'p3' });
		game.act({ type: 'hit', by: 'p1', decisionId: id });
		expect(game.row('p1')).toEqual([5, 8]);
	});
});

describe('disconnects (Rules §12.3)', () => {
	it('a disconnected player who times out stays, so a lost connection never busts them', () => {
		const game = play(2, [5, 6, 7]);
		game.act({ type: 'disconnect', playerId: 'p1' });
		game.tick(15_000);
		expect(types(game.runDue())).toContain('autoStayed');
		expect(game.player('p1').status).toBe('stayed');
	});

	it('…but hits when Stay isn’t allowed', () => {
		const game = play(2, ['+4', 6, 7]);
		game.act({ type: 'disconnect', playerId: 'p1' });
		game.tick(15_000);
		expect(types(game.runDue())).toContain('autoHit');
	});

	it('keeps the seat for 2 minutes, then removes the player', () => {
		const game = play(3, [5, 6, 7]);
		game.act({ type: 'disconnect', playerId: 'p3' });
		game.tick(119_999);
		expect(game.reject({ type: 'graceExpired', playerId: 'p3' })).toBe('TOO_EARLY');
		game.tick(1);
		game.act({ type: 'graceExpired', playerId: 'p3' });
		expect(game.player('p3').status).toBe('left');
	});

	it('a player who reconnects within the grace period keeps their seat and cards', () => {
		const game = play(2, [5, 6, 7]);
		game.act({ type: 'disconnect', playerId: 'p2' });
		game.tick(60_000);
		game.act({ type: 'reconnect', playerId: 'p2' });
		expect(game.player('p2')).toMatchObject({ connected: true, status: 'active', disconnectedAt: undefined });
		expect(game.row('p2')).toEqual([6]);
	});
});

describe('leaving (Rules §12.4)', () => {
	it('scores 0 for the round, keeps cards on the table, and skips the player', () => {
		const game = play(3, [5, 6, 7]);
		game.act({ type: 'quit', by: 'p1' }); // during p1's own decision
		expect(game.player('p1').status).toBe('left');
		expect(game.row('p1')).toEqual([5]);
		expect(game.decision.playerId).toBe('p2');
		game.stay();
		const scored = ofType(game.stay(), 'roundScored')[0]!;
		expect(scored.scores[0]).toMatchObject({ playerId: 'p1', roundScore: 0, total: 0 });
	});

	it('can’t be targeted', () => {
		const game = play(3, [5, 6, 7, 'freeze']);
		game.act({ type: 'quit', by: 'p3' });
		game.hit(); // p1 draws the Freeze
		expect(game.choice.targets).toEqual(['p1', 'p2']);
	});

	it('cancels their Draw Three, and picks their open prompt at random right away', () => {
		const game = play(3, [5, 6, 7, 'd3', 'freeze', 2]);
		game.hit(); // p1 draws Draw Three
		game.choose('p2'); // p2's Draw Three reveals a Freeze: p2 must choose
		expect(game.decision.playerId).toBe('p2');
		const events = game.act({ type: 'quit', by: 'p2' });
		expect(['p1', 'p3']).toContain(ofType(events, 'actionPlayed')[0]!.target);
		expect(ofType(events, 'drawThreeEnded')[0]).toMatchObject({ playerId: 'p2', reason: 'left' });
		expect(game.topOfDeck()).toBe('2');
	});

	it('passes the Dealer role to the next remaining player', () => {
		const game = play(3, [5, 6, 7]); // Dealer p3; next round's Dealer would be p1
		game.act({ type: 'quit', by: 'p1' });
		game.stay();
		game.stay();
		game.nextRound();
		expect(game.state.dealerId).toBe('p2');
	});

	it('the last player left wins', () => {
		const game = play(2, [5, 6]);
		const events = game.act({ type: 'quit', by: 'p2' });
		expect(ofType(events, 'gameOver')[0]).toMatchObject({ winnerIds: ['p1'], draw: false });
		expect(game.state.phase).toBe('results');
	});

	it('can’t rejoin the game', () => {
		const game = play(3, [5, 6, 7]);
		game.act({ type: 'quit', by: 'p3' });
		expect(game.reject({ type: 'reconnect', playerId: 'p3' })).toBe('NOT_ALLOWED');
	});

	it('passes the host role on', () => {
		const game = play(3, [5, 6, 7]);
		const events = game.act({ type: 'quit', by: 'p1' });
		expect(ofType(events, 'hostChanged')[0]).toMatchObject({ playerId: 'p2' });
	});
});

describe('everyone disconnects (Rules §12.5)', () => {
	function allGone() {
		const game = play(3, [5, 6, 7]);
		for (const id of ['p1', 'p2', 'p3']) game.act({ type: 'disconnect', playerId: id });
		return game;
	}

	it('pauses the game and stops every other timer', () => {
		const game = allGone();
		expect(game.state.phase).toBe('paused');
		expect(dueActions(game.state, game.now + 299_999)).toEqual([]);
		expect(nextDeadline(game.state)).toBe(game.now + 300_000);
	});

	it('continues once 2 players are back, with a fresh timer and a fresh grace period for the rest', () => {
		const game = allGone();
		game.tick(60_000);
		game.act({ type: 'reconnect', playerId: 'p1' });
		expect(game.state.phase).toBe('paused');
		game.tick(10_000);
		const events = game.act({ type: 'reconnect', playerId: 'p2' });
		expect(types(events)).toContain('gameResumed');
		expect(game.state.phase).toBe('turns');
		expect(game.decision.deadline).toBe(game.now + 15_000);
		expect(game.player('p3').disconnectedAt).toBe(game.now);
	});

	it('is abandoned with no result if fewer than 2 come back within 5 minutes', () => {
		const game = allGone();
		game.act({ type: 'reconnect', playerId: 'p1' });
		game.tick(300_000);
		const events = game.runDue();
		expect(types(events)).toEqual(['gameAbandoned']);
		expect(game.state.phase).toBe('abandoned');
		expect(game.state.outcome).toBeUndefined();
	});

	it('keeps a card waiting on a choice of target when the game is abandoned', () => {
		const game = play(2, [5, 'freeze']);
		expect(game.choice.card.kind).toBe('action');
		const card = game.choice.card;
		game.act({ type: 'disconnect', playerId: 'p1' });
		game.act({ type: 'disconnect', playerId: 'p2' });
		game.tick(300_000);
		game.runDue();
		expect(game.state.phase).toBe('abandoned');
		expect(game.state.discard.map((c) => c.id)).toContain(card.id);
	});

	it('refuses moves while paused', () => {
		const game = allGone();
		game.act({ type: 'reconnect', playerId: 'p1' });
		expect(game.reject({ type: 'hit', by: 'p1', decisionId: game.decision.id })).toBe('NOT_ALLOWED');
	});
});

describe('lobby (PRD §4.3–4.4)', () => {
	it('makes the first player host and lists players in the order they joined', () => {
		const game = lobby(3);
		expect(game.state.hostId).toBe('p1');
		expect(game.state.players.map((p) => p.seat)).toEqual([0, 1, 2]);
	});

	it('refuses a 9th player', () => {
		const game = lobby(8);
		expect(game.reject({ type: 'join', playerId: 'p9', token: 't', deviceId: 'd9', nickname: 'Nine' })).toBe('ROOM_FULL');
	});

	it('refuses joins once the game has started', () => {
		const game = play(2, [5, 6]);
		expect(game.reject({ type: 'join', playerId: 'p3', token: 't', deviceId: 'd3', nickname: 'Late' })).toBe('GAME_STARTED');
	});

	it('cleans nicknames and refuses invalid or duplicate ones', () => {
		const game = lobby(1);
		const join = (nickname: string, n: number) => ({ type: 'join' as const, playerId: `x${n}`, token: 't', deviceId: `d${n}`, nickname });
		game.act(join('  عبد   الله  ', 1));
		expect(game.player('x1').nickname).toBe('عبد الله');
		expect(game.reject(join('ALI', 2))).toBe('NICKNAME_TAKEN'); // Latin letters ignore case
		expect(game.reject(join('', 3))).toBe('INVALID_NICKNAME');
		expect(game.reject(join('a'.repeat(17), 4))).toBe('INVALID_NICKNAME');
		expect(game.reject(join('Bad\u0007Name', 5))).toBe('INVALID_NICKNAME');
		expect(game.reject(join('😀', 6))).toBe('INVALID_NICKNAME');
		game.act(join('José', 7)); // decomposed é
		expect(game.reject(join('José', 8))).toBe('NICKNAME_TAKEN'); // composed é: the same after NFC
	});

	it('lets only the host change settings, within the allowed range', () => {
		const game = lobby(2);
		expect(game.reject({ type: 'settings', by: 'p2', mode: 'hard', targetScore: 400 })).toBe('NOT_HOST');
		expect(game.reject({ type: 'settings', by: 'p1', mode: 'hard', targetScore: 425 })).toBe('INVALID_SETTINGS');
		expect(game.reject({ type: 'settings', by: 'p1', mode: 'hard', targetScore: 1050 })).toBe('INVALID_SETTINGS');
		game.act({ type: 'settings', by: 'p1', mode: 'hard', targetScore: 1000 });
		expect(game.state.settings).toEqual({ mode: 'hard', targetScore: 1000 });
	});

	it('needs 2 players and the host to start', () => {
		expect(lobby(1).reject({ type: 'start', by: 'p1' })).toBe('NOT_ENOUGH_PLAYERS');
		expect(lobby(2).reject({ type: 'start', by: 'p2' })).toBe('NOT_HOST');
		const game = lobby(2);
		game.act({ type: 'start', by: 'p1' });
		expect(['dealing', 'turns']).toContain(game.state.phase);
	});

	it('lets the host remove a player in the lobby, and blocks that device from rejoining', () => {
		const game = lobby(3);
		game.act({ type: 'remove', by: 'p1', playerId: 'p2' });
		expect(game.state.players.map((p) => p.id)).toEqual(['p1', 'p3']);
		const rejoin = { type: 'join' as const, playerId: 'p2b', token: 't', deviceId: 'device-p2', nickname: 'New name' };
		expect(game.reject(rejoin)).toBe('REMOVED');
		game.act({ ...rejoin, deviceId: 'another-device' });
	});

	it('never lets the host remove a player during a game', () => {
		const game = play(3, [5, 6, 7]);
		expect(game.reject({ type: 'remove', by: 'p1', playerId: 'p2' })).toBe('NOT_ALLOWED');
	});

	it('makes the next player in seat order host when the host leaves the lobby', () => {
		const game = lobby(3);
		game.act({ type: 'quit', by: 'p1' });
		expect(game.state.hostId).toBe('p2');
	});
});

describe('between games (PRD §4.6)', () => {
	function finished() {
		const game = play(3, [10, 3, 4], { targetScore: 100 });
		game.player('p1').total = 95;
		game.act({ type: 'quit', by: 'p3' });
		game.stay();
		game.stay();
		expect(game.state.phase).toBe('results');
		return game;
	}

	it('lets newcomers in once one player is back, refuses Start until everyone is, then reopens the room', () => {
		const game = finished();
		const newcomer = { type: 'join' as const, playerId: 'p4', token: 't', deviceId: 'd4', nickname: 'New' };
		expect(game.reject(newcomer)).toBe('ROOM_BUSY');
		game.act({ type: 'continue', by: 'p1' });
		expect(game.state.phase).toBe('results');
		// Rules §12.9: one player is back, so the room takes newcomers again.
		game.act(newcomer);
		expect(game.player('p4')).toMatchObject({ returned: true, total: 0, status: 'active' });
		expect(game.state.outcome?.playerIds).toEqual(['p1', 'p2', 'p3']);
		expect(game.reject({ type: 'start', by: 'p1' })).toBe('NOT_ALLOWED');
		const events = game.act({ type: 'continue', by: 'p2' });
		expect(types(events)).toContain('roomReopened');
		expect(game.state.phase).toBe('lobby');
		// The player who left during the game is gone from the room; the newcomer stays.
		expect(game.state.players.map((p) => p.id)).toEqual(['p1', 'p2', 'p4']);
	});

	it('after a game, players who left don’t take a place: the room still holds 8', () => {
		const game = play(8, [10, 3, 4, 5, 6, 7, 8, 9], { targetScore: 100 });
		game.player('p1').total = 95;
		game.act({ type: 'quit', by: 'p8' });
		while (game.state.phase !== 'results') game.stay();
		game.act({ type: 'continue', by: 'p1' });
		game.act({ type: 'join', playerId: 'p9', token: 't9', deviceId: 'd9', nickname: 'Nine' });
		expect(game.reject({ type: 'join', playerId: 'p10', token: 't10', deviceId: 'd10', nickname: 'Ten' })).toBe('ROOM_FULL');
	});

	it('moves everyone into the room after 60 seconds', () => {
		const game = finished();
		game.tick(59_999);
		expect(game.reject({ type: 'returnTimeout' })).toBe('TOO_EARLY');
		game.tick(1);
		game.runDue();
		expect(game.state.phase).toBe('lobby');
	});

	it('resets every total when the next game starts, keeping seat order', () => {
		const game = finished();
		game.act({ type: 'continue', by: 'p1' });
		game.act({ type: 'continue', by: 'p2' });
		game.act({ type: 'join', playerId: 'p4', token: 't', deviceId: 'd4', nickname: 'New' });
		game.act({ type: 'start', by: 'p1' });
		expect(game.state.players.map((p) => [p.id, p.total, p.seat])).toEqual([
			['p1', 0, 0],
			['p2', 0, 1],
			['p4', 0, 2],
		]);
	});

	it('lets the host remove a player who hasn’t come back, which can reopen the room', () => {
		const game = finished();
		game.act({ type: 'continue', by: 'p1' });
		game.act({ type: 'remove', by: 'p1', playerId: 'p2' });
		expect(game.state.phase).toBe('lobby');
	});
});
