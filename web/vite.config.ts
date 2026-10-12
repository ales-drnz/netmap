import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

// In sviluppo le API arrivano dal server (o dal mock) su :8082
const api = process.env.NETMAP_API ?? 'http://127.0.0.1:8082';

export default defineConfig({
  plugins: [sveltekit()],
  server: { proxy: { '/api': { target: api, changeOrigin: true } } },
});
