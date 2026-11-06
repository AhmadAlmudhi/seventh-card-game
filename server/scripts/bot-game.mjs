#!/usr/bin/env node
/**
 * Plays one complete game with bot players against a running server, then exits.
 * It checks the whole stack end to end: room creation, joining, every decision, timers between
 * rounds, and the results screen.
 *
 *   node scripts/bot-game.mjs                                   # against `npm run dev` (localhost:8787)
 *   node scripts/bot-game.mjs https://seventh-card-server.ahmadalmudhi.workers.dev 4 150
 *
 * Arguments: server URL, number of players (2–8), winning score (100–1000).
 */
const [server = 'http://localhost:8787', countArg = '3', targetArg = '100'] = process.argv.slice(2);
const count = Number(countArg);
const target = Number(targetArg);
const NAMES = ['Ali', 'Sara', 'Omar', 'Noura', 'Fahad', 'Reem', 'Khalid', 'Huda'];
const started = Date.now();

const created = await fetch(`${server}/api/rooms`, { method: 'POST' });
if (created.status !== 201) throw new Error(`room creation failed: HTTP ${created.status}`);
const { code } = await created.json();
console.log(`room ${code} on ${server}`);

const wsUrl = `${server.replace(/^http/, 'ws')}/parties/room/${code}`;
const bots = [];
for (let i = 0; i < count; i++) bots.push(await joinBot(NAMES[i], i));

bots[0].send({ type: 'settings', mode: 'normal', targetScore: target });
bots[0].send({ type: 'start' });

const result = await new Promise((resolve, reject) => {
	const timer = setTimeout(() => reject(new Error('game took longer than 10 minutes')), 10 * 60_000);
	bots[0].onUpdate = (message) => {
		if (message.view.phase === 'results') {
			clearTimeout(timer);
			resolve(message.view);
		}
	};
});

const winners = result.outcome.winnerIds.map((id) => result.players.find((p) => p.id === id).nickname);
console.log(`game over after round ${result.round}: ${result.outcome.draw ? 'draw between' : 'winner'} ${winners.join(', ')}`);
for (const p of [...result.players].sort((a, b) => b.total - a.total)) console.log(`  ${p.nickname.padEnd(8)} ${p.total}`);
console.log(`took ${((Date.now() - started) / 1000).toFixed(1)} s`);
for (const bot of bots) bot.close();

/** Connects, joins, and answers its own decisions after a short "thinking" pause. */
async function joinBot(nickname, index) {
	const socket = new WebSocket(wsUrl);
	const deviceId = `bot-${code}-${index}-${Math.random().toString(36).slice(2, 10)}`;
	const answered = new Set();
	const bot = {
		playerId: undefined,
		onUpdate: undefined,
		send: (message) => socket.send(JSON.stringify(message)),
		close: () => socket.close(1000, 'done'),
	};
	await new Promise((resolve, reject) => {
		socket.addEventListener('open', () => bot.send({ type: 'hello', nickname, deviceId }));
		socket.addEventListener('error', () => reject(new Error(`${nickname}: connection failed`)));
		socket.addEventListener('message', (event) => {
			const message = JSON.parse(event.data);
			if (message.type === 'welcome') {
				bot.playerId = message.playerId;
				resolve();
			} else if (message.type === 'error') {
				console.error(`${nickname} got error ${message.code}`);
				if (!bot.playerId) reject(new Error(`${nickname}: ${message.code}`));
			} else if (message.type === 'update') {
				bot.onUpdate?.(message);
				const decision = message.view.decision;
				if (!decision || decision.playerId !== bot.playerId || answered.has(decision.id)) return;
				answered.add(decision.id);
				const me = message.view.players.find((p) => p.id === bot.playerId);
				setTimeout(() => {
					if (decision.kind === 'hit_or_stay') {
						bot.send({ type: decision.canStay && me.row.length >= 3 ? 'stay' : 'hit', decisionId: decision.id });
					} else {
						const others = decision.targets.filter((id) => id !== bot.playerId);
						bot.send({ type: 'choose', decisionId: decision.id, targetId: others[0] ?? decision.targets[0] });
					}
				}, 150);
			}
		});
	});
	return bot;
}
