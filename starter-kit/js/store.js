/* ============================================================================
 * store.js — the user's data, on the user's device.
 *
 * Two things this module exists to enforce:
 *
 * 1. ONE namespaced, versioned key: "<app>:v1". When the shape changes
 *    incompatibly you bump the version and add a migration; you never
 *    silently reinterpret old bytes as new ones. Forest carries live
 *    migrations for five prior versions of its store and has never lost a
 *    user's forest.
 *
 * 2. EVERY access is guarded. A disabled store (Safari private mode), a quota
 *    error, or corrupt JSON must never be able to crash the app. Reads fall
 *    back to a default; writes silently no-op. The `typeof window` guards are
 *    there so the same module can be imported during SSR.
 * ========================================================================= */

const APP = "__APP_SLUG__";
const VERSION = 1;
export const STORAGE_KEY = `${APP}:v${VERSION}`;

/* The shape of a brand-new user. Keep it a function, not a shared object —
 * a shared default gets mutated by the first thing that touches it. */
function defaultState() {
  return {
    v: VERSION,
    createdAt: Date.now(),
    settings: { sound: true },
    // ...your app's state
  };
}

/* ---------------------------------------------------------------------------
 * Migrations. Keyed by the version being migrated FROM. Each returns the next
 * version's shape. They chain, so a v1 save walks all the way to current.
 *
 * Add one every time you bump VERSION. Deleting an old migration strands
 * anyone who has not opened the app since — which, for a local-first app with
 * no backup, means losing their data permanently.
 * ------------------------------------------------------------------------- */
const MIGRATIONS = {
  // 1: (old) => ({ ...old, v: 2, newField: [] }),
};

function migrate(data) {
  let state = data;
  while (state.v < VERSION && MIGRATIONS[state.v]) {
    state = MIGRATIONS[state.v](state);
  }
  // A save from a FUTURE version (user opened a newer deploy on another
  // device, then an older cached one here) is not migratable. Leave it alone
  // rather than corrupting it — worst case this session runs on defaults.
  if (state.v !== VERSION) return null;
  return state;
}

/* --- raw, guarded primitives --------------------------------------------- */

export function readString(key) {
  if (typeof window === "undefined") return null;
  try { return localStorage.getItem(key); } catch { return null; }
}

export function writeString(key, value) {
  if (typeof window === "undefined") return;
  try { localStorage.setItem(key, value); } catch { /* store unavailable */ }
}

export function readFlag(key) {
  return readString(key) === "1";
}

export function writeFlag(key, value = true) {
  if (typeof window === "undefined") return;
  try {
    if (value) localStorage.setItem(key, "1");
    else localStorage.removeItem(key);
  } catch { /* store unavailable */ }
}

/* --- the app's state ------------------------------------------------------ */

export function loadState() {
  const raw = readString(STORAGE_KEY);
  if (!raw) return defaultState();

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return defaultState();  // corrupt JSON — start clean rather than crash
  }

  if (!parsed || typeof parsed !== "object") return defaultState();
  if (typeof parsed.v !== "number") return defaultState();

  const migrated = migrate(parsed);
  if (!migrated) return defaultState();

  // Merge over the defaults so a field added since this save was written
  // exists rather than being undefined at every read site.
  return { ...defaultState(), ...migrated, v: VERSION };
}

export function saveState(state) {
  writeString(STORAGE_KEY, JSON.stringify(state));
}

/* Export/import, so taste/progress data survives a device switch or a cache
 * clear. A local-first app with no export is one "clear browsing data" away
 * from losing everything the user built — worth the twenty lines. */
export function exportState(state) {
  return JSON.stringify({ app: APP, v: VERSION, exportedAt: Date.now(), state }, null, 2);
}

export function importState(json) {
  try {
    const parsed = JSON.parse(json);
    if (!parsed || parsed.app !== APP) return null;
    const migrated = migrate(parsed.state);
    return migrated ? { ...defaultState(), ...migrated, v: VERSION } : null;
  } catch {
    return null;
  }
}
