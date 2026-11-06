import { cloudflareTest } from '@cloudflare/vitest-plugin';
import { defineConfig } from 'vitest/config';

export default defineConfig({
	test: {
		projects: [
			{
				// The rules engine is pure TypeScript, so its tests run in plain Node (fast, and simulations can read env vars).
				test: { name: 'engine', include: ['test/engine/**/*.test.ts'], environment: 'node' },
			},
			{
				// The Worker and the Room Durable Object run inside the real Workers runtime.
				plugins: [
					cloudflareTest({
						wrangler: { configPath: './wrangler.jsonc' },
						// See RATE_LIMIT_PER_SECOND in wrangler.jsonc.
						miniflare: { bindings: { RATE_LIMIT_PER_SECOND: '200' } },
					}),
				],
				// Real WebSockets and paced bots: a full game legitimately takes several seconds.
				test: { name: 'worker', include: ['test/worker/**/*.spec.ts'], testTimeout: 20_000 },
			},
		],
	},
});
