import { readFileSync } from 'node:fs';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

// the app's version, from the one place it lives: the root package.json
const { version } = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8')) as {
  version: string;
};

// In sviluppo le API arrivano dal server (o dal mock) su :8082
const api = process.env.NETMAP_API ?? 'http://127.0.0.1:8082';

export default defineConfig({
  plugins: [sveltekit()],
  define: { __APP_VERSION__: JSON.stringify(version) },
  server: { proxy: { '/api': { target: api, changeOrigin: true } } },
});
