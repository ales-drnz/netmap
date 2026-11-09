import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  resolve: {
    // web/src/lib imports the API types as `$shared/api` (a SvelteKit alias)
    alias: { $shared: fileURLToPath(new URL('./shared', import.meta.url)) },
  },
  test: {
    // server suite + pure web helpers (only plain .ts files: no Svelte runes)
    include: ['server/test/**/*.test.ts', 'web/src/**/*.test.ts'],
    // each file in its own process: a server or timer left open cannot keep
    // the other files alive, and the process always gets closed
    pool: 'forks',
    testTimeout: 30_000,
    hookTimeout: 30_000,
    teardownTimeout: 10_000,
    reporters: process.env.CI ? ['verbose'] : ['default'],
  },
});
