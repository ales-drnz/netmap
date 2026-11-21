// Dropping root.
//
// ZeroTier (as in ZTNET's standard compose) runs as root and writes
// `authtoken.secret` as root:root 0600. A process running as uid 1000 cannot
// read it even with the volume mounted, so the image starts the server as
// root: config.ts reads the token, then this module gives up root for good
// before anything is served, fetched or written. Everything that faces the
// network runs as an unprivileged user, exactly as with `USER node`.

import fs from 'node:fs';
import path from 'node:path';

export interface PrivilegeDeps {
  getuid: () => number | undefined;
  setuid: (id: number) => void;
  setgid: (id: number) => void;
  /** replaces the supplementary groups: root's would otherwise survive setgid */
  setgroups: (groups: number[]) => void;
  mkdir: (dir: string) => void;
  /** null when the path does not exist */
  stat: (p: string) => { uid: number; mode: number } | null;
  chown: (p: string, uid: number, gid: number) => void;
  log: (msg: string) => void;
}

export const nodePrivilegeDeps: PrivilegeDeps = {
  getuid: () => process.getuid?.(),
  setuid: (id) => process.setuid?.(id),
  setgid: (id) => process.setgid?.(id),
  setgroups: (groups) => process.setgroups?.(groups),
  mkdir: (dir) => fs.mkdirSync(dir, { recursive: true }),
  stat: (p) => {
    try {
      const st = fs.statSync(p);
      return { uid: st.uid, mode: st.mode };
    } catch {
      return null;
    }
  },
  chown: (p, uid, gid) => fs.chownSync(p, uid, gid),
  log: (msg) => console.log(msg),
};

export interface DropResult {
  dropped: boolean;
  uid?: number;
  gid?: number;
}

function idFrom(value: string | undefined, name: string, log: (msg: string) => void): number {
  if (value === undefined || value === '') return 1000;
  const n = Number(value);
  if (Number.isInteger(n) && n > 0) return n;
  // 0 would mean "stay root" through the back door: NETMAP_KEEP_ROOT says it explicitly
  log(`${name}=${value} is not a valid non-root id: using 1000`);
  return 1000;
}

/**
 * If running as root, makes the history folder usable by the target user and
 * switches to it (default uid/gid 1000, `node` in node:22-alpine). Does nothing
 * when not root, or when NETMAP_KEEP_ROOT is set.
 */
export function dropPrivileges(
  env: NodeJS.ProcessEnv,
  historyFile: string,
  deps: PrivilegeDeps = nodePrivilegeDeps,
): DropResult {
  if (deps.getuid() !== 0) return { dropped: false };
  if (env.NETMAP_KEEP_ROOT) {
    deps.log('NETMAP_KEEP_ROOT is set: still running as root');
    return { dropped: false };
  }
  const uid = idFrom(env.NETMAP_UID, 'NETMAP_UID', deps.log);
  const gid = idFrom(env.NETMAP_GID, 'NETMAP_GID', deps.log);

  // Volumes created by earlier versions, or by Docker itself for a new named
  // volume, are owned by root: after the drop history could no longer be
  // saved. Fix ownership of the folder and of history.json (+ .tmp) only — never a
  // recursive chown, which on a mistaken HISTORY_FILE could rewrite a whole tree.
  const dir = path.dirname(path.resolve(historyFile));
  try {
    deps.mkdir(dir);
    const st = deps.stat(dir);
    // A world-writable folder (/tmp) is usable anyway, and taking it over would
    // be wrong; `/` is never ours to change.
    if (st && st.uid === 0 && dir !== path.parse(dir).root && (st.mode & 0o002) === 0) {
      deps.chown(dir, uid, gid);
    }
    // the `.tmp` too: a leftover from a save interrupted as root would make
    // the store's atomic write fail on every later save
    const file = path.resolve(historyFile);
    for (const f of [file, `${file}.tmp`]) {
      const fst = deps.stat(f);
      if (fst && fst.uid === 0) deps.chown(f, uid, gid);
    }
  } catch (err) {
    // not fatal: the history store keeps working in memory when it cannot write
    deps.log(`could not prepare ${dir} for uid ${uid}: ${(err as Error).message || err}`);
  }

  // order matters: groups first, then gid, then uid (after setuid there is no
  // permission left to change the others)
  deps.setgroups([gid]);
  deps.setgid(gid);
  deps.setuid(uid);
  deps.log(`started as root to read the ZeroTier token and prepare ${dir}; now running as uid ${uid}, gid ${gid}`);
  return { dropped: true, uid, gid };
}
