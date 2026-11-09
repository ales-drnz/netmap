// Builds dist/: the server as a single file (dist/server.mjs, no node_modules
// needed) next to the compiled web UI in dist/web.
//
//   npm run build     →   node dist/server.mjs
import { cpSync, existsSync, mkdirSync, rmSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const dist = path.join(root, 'dist');

rmSync(dist, { recursive: true, force: true });
mkdirSync(dist, { recursive: true });

await build({
  entryPoints: [path.join(root, 'server/src/index.ts')],
  outfile: path.join(dist, 'server.mjs'),
  bundle: true,
  platform: 'node',
  format: 'esm',
  target: 'node22',
  sourcemap: false,
  legalComments: 'none',
  // inside the bundle the app folder is the bundle's own folder (see config.ts)
  define: { __NETMAP_BUNDLE__: 'true' },
  // some CommonJS dependencies call require(), which ESM lacks: recreate it
  banner: {
    js: "import { createRequire as __netmapCreateRequire } from 'node:module';\nconst require = __netmapCreateRequire(import.meta.url);",
  },
  logLevel: 'info',
});

const web = path.join(root, 'web/build');
if (existsSync(web)) {
  cpSync(web, path.join(dist, 'web'), { recursive: true });
  console.log('web/build/ → dist/web/');
} else {
  console.log('web/build/ missing: run `npm run build:web` first (the UI will answer 404)');
}
