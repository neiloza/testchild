# Bringing Liberty, Clash, Forest and Popcorn up to standard

Written 2026-08-20, against the rules in `APP_DESIGN_RULES.md`.
SlotMachine is deliberately out of scope.

---

## Scope: standard, not kit

**These four apps get brought up to the STANDARD. None of them gets ported
onto the STARTER KIT.** That distinction is the whole shape of this plan.

The kit exists so app #6 starts correct. Retrofitting it onto working apps
would mean rewriting Forest's 2,000-line `app.js` to use ES modules, replacing
Clash's React shell, and re-theming Liberty away from Tailwind — weeks of
risk, in exchange for nothing a user would notice. Every item below is a
targeted change to an existing file.

Where an app deliberately breaks a rule for a good reason, the fix is to
**write the reason down**, not to change the code. Liberty's near-empty
service worker is the clearest case: it caches one file on purpose, because a
shell-caching worker would eventually pin a reader to a stale bill. That is
correct and must not be "fixed."

---

## Audit — what each app is actually missing

Verified by reading the repos, not assumed.

| | Liberty | Clash | Forest | Popcorn |
|---|---|---|---|---|
| Data export / import | n/a (server) | **missing** | **missing** | **missing** |
| `navigator.storage.persist()` | n/a | **missing** | **missing** | **missing** |
| Smoke test | **missing** | **missing** | **missing** | **missing** |
| CI runs the tests | **missing** (18 test files) | **missing** (16 test files) | n/a (no tests) | n/a (no tests) |
| Service worker | ok (minimal, deliberate) | **missing entirely** | ok | ok |
| `:focus-visible` | ok | ok | **missing** | ok |
| `@media (hover: hover)` | ok (Tailwind v4 default) | **missing** (28 rules) | n/a (0 hover rules) | ok (already guarded) |
| `prefers-reduced-motion` | ok | ok | ok (inverted form) | ok |
| README + CLAUDE.md | ok | ok | ok | ok |
| Install prompt UI | ok | ok | none (has APK) | ok |

Three things fall out of that table:

1. **Nothing here is a redesign.** The gaps are small and specific.
2. **The data-durability gap is universal** and is the only one where the
   user loses something real.
3. **Liberty and Clash have 34 test files that no workflow runs.** That is
   the largest amount of value already paid for and not collected.

---

## Phase 0 — Data durability (all four, do this first)

Nothing else on this list can cost a user their data. This can.

Installing helps on iOS, where a PWA gets its own storage container that
survives clearing Safari's history, and where installing lifts the 7-day
eviction rule. It helps much less on Android, where an installed PWA shares
origin storage with Chrome — "Clear cookies and site data" takes it. And it
helps not at all against a lost phone or a new device.

**0.1 — Request persistent storage.** Three lines, all four apps, on startup.
None of the five apps does this today.

```js
if (navigator.storage?.persist) {
  navigator.storage.persist();   // ask to be exempt from automatic eviction
}
```

This protects against the browser reclaiming space under pressure. It does
**not** protect against a user deliberately clearing data — nothing does. Do
not let it substitute for 0.2.

**0.2 — Export and import.** Clash, Forest, Popcorn. Popcorn's own `CLAUDE.md`
has been carrying this as an open issue.

- A **Download backup** button in Settings that writes a `.json` file.
- An **Import** control that reads one back, validating the `app` field so a
  Forest backup cannot be loaded into Popcorn.
- The kit's `js/store.js` has a working `exportState`/`importState` pair to
  copy. Forest's must be rewritten in `var`/`function` style — see its note
  below.

**0.3 — Say so in the UI.** One line in Settings: *"Your data is stored on this
device only. Download a backup before switching phones or clearing browser
data."* The honest version of the trade-off, where the user can act on it.

**Order:** Forest first. It is the app where loss hurts most — a forest
represents months of accumulated sessions, and there is no way to get it back.

---

## Phase 1 — Run the tests that already exist (Liberty, Clash)

34 test files, zero automated runs. Roughly 20 lines of YAML each.

**Liberty** — `.github/workflows/ci.yml`, on push and PR:
`npm ci`, then `npm run lint`, `npm run typecheck`, `npm test`.

**Clash** — same shape with pnpm: `pnpm install --frozen-lockfile`, then
`pnpm -r typecheck` and `pnpm -r test`.

Do this before any of the code changes below, so the changes land on a branch
that CI is watching. This is the single highest-leverage item in the document
and the cheapest.

---

## Phase 2 — Per-app work

Ordered least-risk first, so momentum builds on the safest changes.

### Popcorn — closest to standard

Everything structural is already in place, including the hover guard that no
other app has.

1. Export/import per Phase 0.
2. Add `test/smoke.mjs`. Popcorn is the app that most needs one: its own notes
   say the clustering and recommendation logic has "no regression safety net."
   Beyond the kit's shell checks, cover: add-to-favorites persists across a
   reload, three favorites unlock the For You tab, and a legacy single-category
   save still migrates.
3. Delete the dead `derivedRatingCeiling()` / `derivedVoteCeiling()` path and
   its `LEGACY_*` branches — flagged as inert in `CLAUDE.md` since the catalog
   gained real `r` and `v`. Confirm no old save still needs it before removing.
4. Consider moving `ov` (overview text) into a third lazily-loaded tier. The
   notes record `js/movies.js` growing from 1.8MB to 3.5MB when descriptions
   landed, and it is precached, so every install pays for it.

### Forest — one gap, one constraint

1. Add `:focus-visible`. Forest is the only one of the four without it. Use
   Liberty's form so it stays consistent:

   ```css
   :where(a, button, input, [tabindex]):focus-visible {
     outline: 2px solid var(--leaf-deep);
     outline-offset: 2px;
     border-radius: 4px;
   }
   ```

2. Export/import per Phase 0 — **the highest-value single change in this
   document.**
3. Add a smoke test. Beyond the shell: a session completes and plants a tree,
   a backgrounded session withers, and a v1-through-v5 save still migrates.
   That migration chain is five versions deep and entirely untested.
4. **Constraint that governs all Forest work:** `app.js` is written in
   `var` and function declarations with zero arrow functions, deliberately, for
   WebView compatibility with the Android APK wrapper. Any code copied from the
   kit must be rewritten in that style. Do not introduce `const`/`let`, arrow
   functions, or ES modules here.

No hover guard needed — Forest has no `:hover` rules at all.

### Clash — the largest gap

1. **Decide the service worker.** Clash ships a manifest and full install
   support but no worker, so it installs and then does not work offline. Two
   honest options:
   - *Add one.* Deck building, collection browsing and the tutorial are all
     local; only live multiplayer needs the network. Use the kit's
     network-first worker, and precache the built assets rather than sources
     (Clash has a build step, so the shell list has to come from the Vite
     manifest, not a hand-written array).
   - *Or drop the offline claim* and note in `CLAUDE.md` that Clash is
     installable-but-online-only, on purpose.

   Adding one is the better call — an installed icon that fails on a train
   reads as broken.
2. Move all 28 `:hover` rules into `@media (hover: hover)` blocks. Clash is a
   tap-driven game, so the stuck-hover bug this prevents is most visible here.
   Mechanical but touches six stylesheets; do it as its own commit.
3. Export/import for collection and decks. Note `collection.ts` and `decks.ts`
   have their own bespoke parsers and migrations — the export has to go through
   those, not around them.
4. Smoke test for the client shell. The engine already has 16 tests; the shell
   has none.

### Liberty — mostly documentation

1. CI, per Phase 1. Most valuable here of anywhere: the ingestion pipeline can
   silently fill tables with plausible-but-wrong data, and `CLAUDE.md` records
   that exact failure happening twice.
2. **Write down the deliberate exceptions** so no future session "fixes" them:
   - the near-empty service worker (a reading tool must not serve a stale bill)
   - no `user-select: none` (it is a reading app; selection is the point)
   - no local-first storage (server-backed by nature)

   Add these to the "Invariants" section as *rules it intentionally breaks and
   why*. This is the whole Liberty task, and it is worth more than any code
   change on this list.
3. Split `CLAUDE.md`. At 3,006 lines it is loaded into every session, and some
   of it is certainly stale — a stale *why* is worse than none, because it
   reads authoritative. Keep a live file of roughly 300 lines (current state,
   invariants, next steps, waiting-on-a-human) and move the rest to
   `docs/HISTORY.md`.
4. Optional: a smoke test against a running dev server. Lower value than
   elsewhere, since 18 unit tests already cover the logic that matters.

---

## Phase 3 — Keep it from drifting again

1. **A conformance script.** Most of the checklist is mechanically checkable:
   manifest icon sizes, presence of `README.md`/`CLAUDE.md`, `dvh` usage, a
   `prefers-reduced-motion` block, `:focus-visible`, hover rules outside a
   guard, any analytics script. One `conformance.mjs` pointed at any repo turns
   this document from something to remember into something that reports.
2. **A kit-drift check.** `install.js`, `store.js` and the CSS layers now exist
   in several places. A script that diffs an app's vendored copy against the kit
   makes divergence visible. Vendoring is fine; silent vendoring is how the
   install table ended up written twice.
3. **"Waiting on a human" in all four `CLAUDE.md` files.** Only Liberty has it,
   and it is the best idea in the set — the explicit boundary between what an
   agent can finish and what only you can unblock.

---

## Suggested order

| Step | Work | Why here |
|---|---|---|
| 1 | Liberty + Clash CI | Cheapest, protects everything after it |
| 2 | Forest export/import + persist | Highest user-visible risk |
| 3 | Popcorn export/import + smoke test | Easiest app; builds the pattern |
| 4 | Clash export/import + hover guard | Mechanical, medium size |
| 5 | Clash service worker | Needs the decision above first |
| 6 | Forest focus-visible + smoke test | Small |
| 7 | Liberty invariants + CLAUDE.md split | Documentation, no runtime risk |
| 8 | Conformance + drift scripts | Locks in everything above |

Steps 1–3 capture most of the value. If the work stalls after step 3, the
apps are still meaningfully better off.

---

## Do not do

- **Do not port any of these onto the starter kit.** Weeks of risk, nothing a
  user would notice.
- **Do not add a build step to Forest or Popcorn.** Their lack of one is why
  they still run untouched.
- **Do not make Liberty cache its app shell.** It is a reading tool; the
  restraint is the design.
- **Do not add `user-select: none` to Liberty.** Same reason.
- **Do not rewrite Forest in modern JS.** The `var`/function style is load
  bearing for the Android WebView.
- **Do not treat `navigator.storage.persist()` as a substitute for export.**
  It prevents automatic eviction, not deliberate clearing, and not a lost phone.
