import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['server/test/**/*.test.ts'],
    // each file in its own process: a server or timer left open cannot keep
    // the other files alive, and the process always gets closed
    pool: 'forks',
    testTimeout: 30_000,
    hookTimeout: 30_000,
    teardownTimeout: 10_000,
    reporters: process.env.CI ? ['verbose'] : ['default'],
  },
});
