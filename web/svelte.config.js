import adapter from '@sveltejs/adapter-static';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

// Static SPA: the Node server serves these files and answers the API.
// BASE_PATH lets it live under a sub-path behind a reverse proxy.
const base = process.env.BASE_PATH ?? '';

/** @type {import('@sveltejs/kit').Config} */
export default {
  preprocess: vitePreprocess(),
  kit: {
    adapter: adapter({ fallback: 'index.html', strict: false }),
    paths: { base, relative: false },
    alias: { $shared: '../shared' },
  },
};
