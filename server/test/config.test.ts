import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { AUTHTOKEN_FILE, classifyTokenError, loadConfig } from '../src/config.js';

const BASE_ENV = { ZTNET_API_TOKEN: 't', ZTNET_NETWORK_ID: 'abcdef1234567890' };
const errno = (code: string) => Object.assign(new Error(code), { code });

function load(env: NodeJS.ProcessEnv, readAuthtoken?: (f: string) => string) {
  const logs: string[] = [];
  const config = loadConfig({ ...BASE_ENV, ...env }, { readAuthtoken, getuid: () => 1000, log: (m) => logs.push(m) });
  return { config, logs };
}

describe('config: ZeroTier token', () => {
  it('ZT_AUTHTOKEN wins and the file is not even read', () => {
    const { config, logs } = load({ ZT_AUTHTOKEN: ' abc \n' }, () => {
      throw new Error('must not be called');
    });
    expect(config.ztToken).toBe('abc');
    expect(config.ztTokenError).toBeNull();
    expect(logs).toEqual([]);
  });

  it('reads the default file, or ZT_AUTHTOKEN_FILE', () => {
    const seen: string[] = [];
    const read = (f: string) => {
      seen.push(f);
      return 'tok\n';
    };
    expect(load({}, read).config.ztToken).toBe('tok');
    expect(load({ ZT_AUTHTOKEN_FILE: '/x/token' }, read).config.ztTokenError).toBeNull();
    expect(seen).toEqual([AUTHTOKEN_FILE, '/x/token']);
  });

  it.each([
    ['EACCES', 'token-unreadable', /not readable by uid 1000/],
    ['ENOENT', 'token-missing', /not found at/],
    ['EIO', 'token-error', /failed \(EIO\)/],
  ])('%s → %s, with a message that says what to do', (code, kind, msg) => {
    const { config, logs } = load({}, () => {
      throw errno(code);
    });
    expect(config.ztToken).toBe('');
    expect(config.ztTokenError).toBe(kind);
    expect(logs).toHaveLength(1);
    expect(logs[0]).toMatch(msg);
    expect(logs[0]).toContain(AUTHTOKEN_FILE);
    expect(logs[0]).toContain('ZT_AUTHTOKEN');
  });

  it('an empty file is an error, not a token', () => {
    expect(load({}, () => '  \n').config.ztTokenError).toBe('token-error');
  });

  it('classifyTokenError', () => {
    expect(classifyTokenError(errno('EPERM'))).toBe('token-unreadable');
    expect(classifyTokenError(errno('ENOTDIR'))).toBe('token-missing');
    expect(classifyTokenError(new Error('x'))).toBe('token-error');
    expect(classifyTokenError(null)).toBe('token-error');
  });

  // the real filesystem, not an injected reader: root reads anything, so the
  // EACCES half only makes sense as a normal user
  it('real files: missing and (as non-root) mode 000', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'netmap-cfg-'));
    try {
      const file = path.join(dir, 'authtoken.secret');
      const missing = loadConfig({ ...BASE_ENV, ZT_AUTHTOKEN_FILE: file }, { log: () => {} });
      expect(missing.ztTokenError).toBe('token-missing');
      fs.writeFileSync(file, 'secret');
      fs.chmodSync(file, 0o000);
      const locked = loadConfig({ ...BASE_ENV, ZT_AUTHTOKEN_FILE: file }, { log: () => {} });
      if (process.getuid?.() === 0) expect(locked.ztToken).toBe('secret');
      else expect(locked.ztTokenError).toBe('token-unreadable');
    } finally {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  });
});
