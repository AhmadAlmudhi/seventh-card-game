/**
 * Records one round of the real engine as the updates a player's app would receive, for the screen
 * gallery's playback demo and performance check (PRD §6.0's worst case: 8 players, a Flip Three,
 * then a Seventh Card).
 *
 *   npx esbuild scripts/record-replay.ts --bundle --platform=node --format=esm --outfile=/tmp/rr.mjs
 *   node /tmp/rr.mjs ../lib/dev/replays/worst_case.json
 *
 * It searches seeds for a round with every wanted moment, then writes: a snapshot of the table just
 * before that round, followed by every update of the round.
 */
import { writeFileSync } from 'node:fs';
import { applyAction, createRoom, dueActions, publicView, type Action, type GameEvent, type GameState } from '../src/engine/engine';
import { seededRng } from '../src/engine/rng';

const NAMES = ['عبدالله', 'سارة', 'Omar', 'نورة', 'فهد', 'Reem', 'خالد', 'هدى'];
const WANTED = ['flipThreeStarted', 'seventhCard', 'busted'];

interface Update {
	version: number;
	now: number;
	events: GameEvent[];
	view: ReturnType<typeof publicView>;
}

function play(seed: number): { before: Update; round: Update[] } | undefined {
	const engineRng = seededRng(seed);
	const botRng = seededRng(seed * 31 + 7);
	let now = 1_800_000_000_000;
	let state: GameState = createRoom();
	let version = 0;
	let updates: Update[] = [];
	let before: Update | undefined;

	const apply = (action: Action): boolean => {
		const result = applyAction(state, action, { rng: engineRng, now });
		if (!result.ok) return false;
		state = result.state;
		state.version = ++version;
		if (result.events.some((e) => e.type === 'roundStarted')) {
			// A new round: keep only the table as it was just before it.
			before = updates.at(-1);
			updates = [];
		}
		updates.push({ version, now, events: result.events, view: publicView(state) });
		return true;
	};

	for (let i = 0; i < 8; i++) apply({ type: 'join', playerId: `p${i + 1}`, token: `t${i}`, deviceId: `device-${i}`, nickname: NAMES[i]! });
	apply({ type: 'settings', by: 'p1', mode: 'normal', targetScore: 300 });
	apply({ type: 'start', by: 'p1' });

	for (let step = 0; step < 3000; step++) {
		if (state.phase === 'round_over' || state.phase === 'results') {
			const seen = new Set(updates.flatMap((u) => u.events.map((e) => e.type)));
			if (before && WANTED.every((t) => seen.has(t)) && state.round > 1) return { before, round: updates };
			if (state.phase === 'results') return undefined;
			now = state.nextRoundAt!;
			apply(dueActions(state, now)[0]!.action);
			continue;
		}
		const decision = state.decision;
		if (!decision) return undefined;
		now += 900;
		const me = state.players.find((p) => p.id === decision.playerId)!;
		if (decision.kind === 'hit_or_stay') {
			const stay = decision.canStay && me.row.length >= 3 && botRng.int(3) > 0;
			apply({ type: stay ? 'stay' : 'hit', by: me.id, decisionId: decision.id });
		} else {
			const targetId = decision.targets[botRng.int(decision.targets.length)]!;
			apply({ type: 'choose', by: me.id, decisionId: decision.id, targetId });
		}
	}
	return undefined;
}

const out = process.argv[2] ?? 'replay.json';
for (let seed = 1; seed < 5000; seed++) {
	const found = play(seed);
	if (!found) continue;
	const events = found.round.reduce((n, u) => n + u.events.length, 0);
	writeFileSync(out, JSON.stringify({ seed, playerId: 'p1', before: found.before, updates: found.round }));
	console.log(`seed ${seed}: round ${found.round.at(-1)!.view.round}, ${found.round.length} updates, ${events} events -> ${out}`);
	break;
}
