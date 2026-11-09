// See https://svelte.dev/docs/kit/types#app.d.ts
declare global {
  namespace App {}
  /** the Netmap version (root package.json), set by vite.config.ts */
  const __APP_VERSION__: string;
}
export {};
