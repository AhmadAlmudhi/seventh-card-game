/**
 * Worker entry point (PRD §8.2).
 *
 * - `POST /api/rooms` creates a room and returns its code. A JSON body `{"tutorial": true}` makes a
 *   tutorial room instead: one player against the bot (PRD §4.9).
 * - `/parties/room/:code` opens the room's WebSocket.
 * - `GET /` is a health check.
 */
import { getServerByName, routePartykitRequest } from 'partyserver';
import { z } from 'zod';
import type { Room } from './room';
import { generateRoomCode, isRoomCode } from './util/roomCode';

export { Room } from './room';

const CREATE_ATTEMPTS = 5;
const MAX_BODY_BYTES = 256;

const CreateRoomBody = z.object({ tutorial: z.boolean().optional() }).strict();

export default {
	async fetch(request, env): Promise<Response> {
		const url = new URL(request.url);
		const origin = request.headers.get('Origin');

		if (url.pathname === '/api/rooms') return createRoom(request, env, origin);

		if (request.method === 'GET' && url.pathname === '/') {
			return Response.json({ name: 'seventh-card-server', status: 'ok' });
		}

		const routed = await routePartykitRequest(request, env, {
			onBeforeConnect: (req, lobby) => {
				if (!isRoomCode(lobby.name)) return new Response('Not Found', { status: 404 });
				if (!isAllowedOrigin(req.headers.get('Origin'), env)) return new Response('Forbidden', { status: 403 });
			},
			// Rooms are only reached over WebSocket.
			onBeforeRequest: () => new Response('Not Found', { status: 404 }),
		});
		return routed ?? new Response('Not Found', { status: 404 });
	},
} satisfies ExportedHandler<Env>;

/** Creates a room with a fresh code; retries if the code is taken (PRD §8.2). */
async function createRoom(request: Request, env: Env, origin: string | null): Promise<Response> {
	const cors = corsHeaders(origin, env);
	if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
	if (request.method !== 'POST') return new Response('Method Not Allowed', { status: 405, headers: { ...cors, Allow: 'POST, OPTIONS' } });
	if (!isAllowedOrigin(origin, env)) return new Response('Forbidden', { status: 403 });

	const options = await readOptions(request);
	if (!options) return Response.json({ error: 'INVALID_MESSAGE' }, { status: 400, headers: cors });

	for (let attempt = 0; attempt < CREATE_ATTEMPTS; attempt++) {
		const code = generateRoomCode();
		const stub = await getServerByName<Env, Room>(env.Room, code);
		if (await stub.init(options)) return Response.json({ code }, { status: 201, headers: cors });
	}
	return Response.json({ error: 'NO_CODE_AVAILABLE' }, { status: 503, headers: cors });
}

/** The room options in the request body. An empty body is a normal room; anything invalid is null. */
async function readOptions(request: Request): Promise<{ tutorial?: boolean } | null> {
	const text = await request.text();
	if (text.trim() === '') return {};
	if (text.length > MAX_BODY_BYTES) return null;
	try {
		const parsed = CreateRoomBody.safeParse(JSON.parse(text));
		return parsed.success ? parsed.data : null;
	} catch {
		return null;
	}
}

/**
 * The web app's own site, plus localhost for development (PRD §8.7). The mobile apps send no
 * Origin header, so a missing Origin is allowed.
 */
export function isAllowedOrigin(origin: string | null, env: Env): boolean {
	if (origin === null) return true;
	let url: URL;
	try {
		url = new URL(origin);
	} catch {
		return false;
	}
	if (url.hostname === 'localhost' || url.hostname === '127.0.0.1') return true;
	const allowed = env.ALLOWED_ORIGINS.split(',').map((o) => o.trim());
	return allowed.includes(url.origin);
}

function corsHeaders(origin: string | null, env: Env): Record<string, string> {
	if (!origin || !isAllowedOrigin(origin, env)) return {};
	return {
		'Access-Control-Allow-Origin': origin,
		'Access-Control-Allow-Methods': 'POST, OPTIONS',
		'Access-Control-Allow-Headers': 'Content-Type',
		'Access-Control-Max-Age': '86400',
		Vary: 'Origin',
	};
}
