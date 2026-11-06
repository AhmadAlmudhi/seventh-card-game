/**
 * Worker entry point.
 *
 * M0 only answers a health check at `/`, so a deploy can be confirmed from a browser.
 * Room creation (`POST /api/rooms`) and the Room Durable Object come in M2 (PRD §8.2–8.3).
 */
export default {
	async fetch(request): Promise<Response> {
		const url = new URL(request.url);

		if (request.method === 'GET' && url.pathname === '/') {
			return Response.json({ name: 'seventh-card-server', status: 'ok' });
		}

		return new Response('Not Found', { status: 404 });
	},
} satisfies ExportedHandler<Env>;
