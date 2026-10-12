// Small helpers for reading untrusted JSON: ZTNET and ZeroTier service
// responses change shape between versions, and an unexpected shape must degrade
// (missing field → null), not crash the server.

export type Rec = Record<string, unknown>;

export const isRec = (v: unknown): v is Rec => typeof v === 'object' && v !== null;

/** the object if it is an object, otherwise `{}`: equivalent to reading with `?.` */
export const rec = (v: unknown): Rec => (isRec(v) ? v : {});

export const arr = (v: unknown): unknown[] => (Array.isArray(v) ? v : []);
