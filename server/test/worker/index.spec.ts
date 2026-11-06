import { SELF } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';

describe('worker entry', () => {
	it('answers the health check', async () => {
		const response = await SELF.fetch('https://example.com/');

		expect(response.status).toBe(200);
		expect(await response.json()).toEqual({ name: 'seventh-card-server', status: 'ok' });
	});

	it('returns 404 for unknown paths', async () => {
		const response = await SELF.fetch('https://example.com/nope');

		expect(response.status).toBe(404);
	});

	it('returns 404 for non-GET requests to the health check', async () => {
		const response = await SELF.fetch('https://example.com/', { method: 'POST' });

		expect(response.status).toBe(404);
	});
});
