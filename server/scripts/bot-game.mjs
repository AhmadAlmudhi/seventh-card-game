#!/usr/bin/env node
/**
 * Bot players, for testing.
 *
 * Play one complete bot-only game (checks the whole stack end to end), then exit:
 *   node scripts/bot-game.mjs                                   # against `npm run dev` (localhost:8787)
 *   node scripts/bot-game.mjs https://seventh-card-server.ahmadalmudhi.workers.dev 4 150
 *   (server URL, number of players 2–8, winning score 100–1000)
 *
 * Or fill seats in a room you created in the app, so a play-test needs fewer people:
 *   node scripts/bot-game.mjs https://seventh-card-server.ahmadalmudhi.workers.dev 2 --join K7Q2M
 * The bots join, wait for the host to start, play at a human pace, tap Continue after each game,
 * and stay until you press Ctrl+C or remove them.
 */
const args = process.argv.slice(2);
const joinIndex = args.indexOf('--join');
const joinCode = joinIndex >= 0 ? args[joinIndex + 1]?.toUpperCase() : undefined;
const positional = args.filter((_, i) => joinIndex < 0 || (i !== joinIndex && i !== joinIndex + 1));
const [server = 'http://localhost:8787', countArg = joinCode ? '2' : '3', targetArg = '100'] = positional;
const count = Number(countArg);
const target = Number(targetArg);
const NAMES = ['Ali', 'Sara', 'Omar', 'Noura', 'Fahad', 'Reem', 'Khalid', 'Huda', 'Bot A', 'Bot B', 'Bot C'];
const THINK_MS = joinCode ? 900 : 150;
const started = Date.now();

let code = joinCode;
if (!code) {
	const created = await fetch(`${server}/api/rooms`, { method: 'POST' });
	if (created.status !== 201) throw new Error(`room creation failed: HTTP ${created.status}`);
	({ code } = await created.json());
}
console.log(`room ${code} on ${server}`);
const wsUrl = `${server.replace(/^http/, 'ws')}/parties/room/${code}`;

const bots = [];
let nameIndex = 0;
for (let i = 0; i < count; i++) bots.push(await joinBot(i));

if (joinCode) {
	console.log(`${bots.length} bots joined (${bots.map((b) => b.nickname).join(', ')}). Start the game from the app. Ctrl+C to stop.`);
	await new Promise((resolve) => {
		let open = bots.length;
		for (const bot of bots) bot.onClosed = () => --open === 0 && resolve();
	});
	console.log('all bots have left the room');
} else {
	bots[0].send({ type: 'settings', mode: 'normal', targetScore: target });
	bots[0].send({ type: 'start' });
	const result = await new Promise((resolve, reject) => {
		const timer = setTimeout(() => reject(new Error('game took longer than 10 minutes')), 10 * 60_000);
		bots[0].onResults = (view) => {
			clearTimeout(timer);
			resolve(view);
		};
	});
	const winners = result.outcome.winnerIds.map((id) => result.players.find((p) => p.id === id).nickname);
	console.log(`game over after round ${result.round}: ${result.outcome.draw ? 'draw between' : 'winner'} ${winners.join(', ')}`);
	for (const p of [...result.players].sort((a, b) => b.total - a.total)) console.log(`  ${p.nickname.padEnd(8)} ${p.total}`);
	console.log(`took ${((Date.now() - started) / 1000).toFixed(1)} s`);
	for (const bot of bots) bot.close();
}

/** Connects and joins, trying the next name if one is taken, then answers its own decisions. */
async function joinBot(index) {
	for (;;) {
		const nickname = NAMES[nameIndex++ % NAMES.length];
		const result = await connect(nickname, index);
		if (result.ok) return result.bot;
		if (result.code !== 'NICKNAME_TAKEN') throw new Error(`${nickname} could not join: ${result.code}`);
	}
}

function connect(nickname, index) {
	return new Promise((resolve, reject) => {
		const socket = new WebSocket(wsUrl);
		const deviceId = `bot-${code}-${index}-${Math.random().toString(36).slice(2, 10)}`;
		const answered = new Set();
		const bot = {
			nickname,
			playerId: undefined,
			onResults: undefined,
			onClosed: undefined,
			send: (message) => socket.send(JSON.stringify(message)),
			close: () => socket.close(1000, 'done'),
		};
		let continued = false;
		socket.addEventListener('open', () => bot.send({ type: 'hello', nickname, deviceId }));
		socket.addEventListener('error', () => reject(new Error(`${nickname}: connection failed`)));
		socket.addEventListener('close', () => bot.onClosed?.());
		socket.addEventListener('message', (event) => {
			const message = JSON.parse(event.data);
			if (message.type === 'welcome') {
				bot.playerId = message.playerId;
				resolve({ ok: true, bot });
			} else if (message.type === 'error') {
				if (!bot.playerId) resolve({ ok: false, code: message.code });
				else if (message.code !== 'STALE') console.error(`${nickname} got error ${message.code}`);
			} else if (message.type === 'update') {
				const view = message.view;
				if (view.phase === 'results') {
					bot.onResults?.(view);
					const me = view.players.find((p) => p.id === bot.playerId);
					if (joinCode && me && !me.returned && !continued) {
						continued = true;
						setTimeout(() => bot.send({ type: 'continue' }), 2500);
					}
					return;
				}
				continued = false;
				const decision = view.decision;
				if (!decision || decision.playerId !== bot.playerId || answered.has(decision.id)) return;
				answered.add(decision.id);
				const me = view.players.find((p) => p.id === bot.playerId);
				setTimeout(() => {
					if (decision.kind === 'hit_or_stay') {
						bot.send({ type: decision.canStay && me.row.length >= 3 ? 'stay' : 'hit', decisionId: decision.id });
					} else {
						const others = decision.targets.filter((id) => id !== bot.playerId);
						bot.send({ type: 'choose', decisionId: decision.id, targetId: others[0] ?? decision.targets[0] });
					}
				}, THINK_MS);
			}
		});
	});
}
