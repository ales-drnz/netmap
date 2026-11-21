// Builds the Flutter web app (app/) into app/build/web, with the version from
// package.json baked in. Everything the page needs is bundled: engine
// (--no-web-resources-cdn), fonts and icons, so it works with no internet.
//
//   npm run build:web     →   app/build/web
//
// Wasm (skwasm) where the browser supports it, JavaScript (CanvasKit) as the
// automatic fallback: both are in the build, the loader picks one.
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const { version } = JSON.parse(readFileSync(path.join(root, 'package.json'), 'utf8'));
const flutter = process.env.FLUTTER || 'flutter';

const args = [
  'build',
  'web',
  '--release',
  '--wasm',
  '--no-web-resources-cdn',
  '--base-href=/',
  '--no-wasm-dry-run',
  `--dart-define=NETMAP_VERSION=${version}`,
  // Flutter's own version.json says the same version
  `--build-name=${version}`,
];
console.log(`${flutter} ${args.join(' ')}`);
const r = spawnSync(flutter, args, {
  cwd: path.join(root, 'app'),
  stdio: 'inherit',
  shell: process.platform === 'win32',
});
process.exit(r.status ?? 1);
