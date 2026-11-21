import { describe, expect, it } from 'vitest';
import { dropPrivileges, type PrivilegeDeps } from '../src/privileges.js';

/** fake process and filesystem: records every call, never really setuid */
function fakeDeps(uid: number | undefined, files: Record<string, { uid: number; mode: number }> = {}) {
  const calls: string[] = [];
  const logs: string[] = [];
  const deps: PrivilegeDeps = {
    getuid: () => uid,
    setuid: (id) => calls.push(`setuid ${id}`),
    setgid: (id) => calls.push(`setgid ${id}`),
    setgroups: (g) => calls.push(`setgroups ${g.join(',')}`),
    mkdir: (d) => {
      calls.push(`mkdir ${d}`);
      files[d] ??= { uid: 0, mode: 0o40755 };
    },
    stat: (p) => files[p] ?? null,
    chown: (p, u, g) => calls.push(`chown ${p} ${u}:${g}`),
    log: (m) => logs.push(m),
  };
  return { deps, calls, logs };
}

describe('dropPrivileges', () => {
  it('not root: does nothing at all', () => {
    const { deps, calls, logs } = fakeDeps(1000);
    expect(dropPrivileges({}, '/data/history.json', deps)).toEqual({ dropped: false });
    expect(calls).toEqual([]);
    expect(logs).toEqual([]);
  });

  it('no getuid (Windows): does nothing', () => {
    const { deps, calls } = fakeDeps(undefined);
    expect(dropPrivileges({}, '/data/history.json', deps).dropped).toBe(false);
    expect(calls).toEqual([]);
  });

  it('root: fixes a root-owned /data and history.json, then drops groups, gid, uid in that order', () => {
    const { deps, calls, logs } = fakeDeps(0, {
      '/data': { uid: 0, mode: 0o40755 },
      '/data/history.json': { uid: 0, mode: 0o100644 },
    });
    expect(dropPrivileges({}, '/data/history.json', deps)).toEqual({ dropped: true, uid: 1000, gid: 1000 });
    expect(calls).toEqual([
      'mkdir /data',
      'chown /data 1000:1000',
      'chown /data/history.json 1000:1000',
      'setgroups 1000',
      'setgid 1000',
      'setuid 1000',
    ]);
    expect(logs).toHaveLength(1);
    expect(logs[0]).toMatch(/as root to read the ZeroTier token.*uid 1000/);
  });

  it('root: leaves alone what is already owned by someone else, and world-writable folders', () => {
    const owned = fakeDeps(0, { '/data': { uid: 1000, mode: 0o40755 } });
    dropPrivileges({}, '/data/history.json', owned.deps);
    expect(owned.calls.filter((c) => c.startsWith('chown'))).toEqual([]);
    const tmp = fakeDeps(0, { '/tmp': { uid: 0, mode: 0o41777 } });
    dropPrivileges({}, '/tmp/history.json', tmp.deps);
    expect(tmp.calls.filter((c) => c.startsWith('chown'))).toEqual([]);
    expect(tmp.calls).toContain('setuid 1000');
  });

  it('NETMAP_UID / NETMAP_GID; invalid or 0 falls back to 1000', () => {
    const custom = fakeDeps(0);
    expect(dropPrivileges({ NETMAP_UID: '1234', NETMAP_GID: '99' }, '/data/h.json', custom.deps)).toEqual({
      dropped: true,
      uid: 1234,
      gid: 99,
    });
    expect(custom.calls).toContain('chown /data 1234:99');
    const bad = fakeDeps(0);
    expect(dropPrivileges({ NETMAP_UID: '0', NETMAP_GID: 'x' }, '/data/h.json', bad.deps)).toMatchObject({
      uid: 1000,
      gid: 1000,
    });
  });

  it('NETMAP_KEEP_ROOT: stays root and says so', () => {
    const { deps, calls, logs } = fakeDeps(0);
    expect(dropPrivileges({ NETMAP_KEEP_ROOT: '1' }, '/data/history.json', deps).dropped).toBe(false);
    expect(calls).toEqual([]);
    expect(logs[0]).toMatch(/NETMAP_KEEP_ROOT/);
  });

  it('a folder that cannot be prepared does not stop the drop', () => {
    const { deps, calls, logs } = fakeDeps(0);
    deps.mkdir = () => {
      throw new Error('read-only file system');
    };
    expect(dropPrivileges({}, '/data/history.json', deps).dropped).toBe(true);
    expect(calls).toContain('setuid 1000');
    expect(logs[0]).toMatch(/could not prepare \/data.*read-only/);
  });
});
