# House rules for building Neil's apps

Derived by reading five shipped apps end to end: **Liberty**, **Forest**,
**SlotMachine** (Lucky Gold Slots), **Popcorn**, and **Clash of History**.

Part 1 is the rule set: almost all of it is a rule because *all five* apps
already do it, plus two additions made by decision and marked as such. Part 2
is the starter kit that makes following Part 1 nearly free. Part 3 is the
review queue — the things **3–4 of the 5** apps do — with what was decided
about each and what is still open.

The shape being described is consistent enough to name: **an installable,
offline-capable, phone-first web app, with no tracking and no monetisation,
that lives on its own subdomain of one shared apex domain and stores the
user's data on the user's device.** Every one of the five is a variation on
that; the differences are stack, not philosophy.

---

## Part 1 — The rules

Rules 1–11 and 13 are rules because *all five* apps already do them. Rules 10b
and 12 were added by decision on 2026-08-20 — they are marked as such, and
they are the only two that are not simply a description of what you already
build.

### 1. It is a PWA, and installability is a feature, not a checkbox

Every app ships a web app manifest with `display: standalone` and
`orientation: portrait`, a full icon set, and the Apple meta tags that the
manifest does not cover.

**Required in every `<head>`:**

```html
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover" />
<meta name="theme-color" content="#RRGGBB" />
<link rel="manifest" href="/manifest.webmanifest" />
<link rel="icon" type="image/svg+xml" href="/icons/favicon.svg" />
<link rel="apple-touch-icon" href="/icons/apple-touch-icon.png" />
<meta name="apple-mobile-web-app-capable" content="yes" />
<meta name="mobile-web-app-capable" content="yes" />
<meta name="apple-mobile-web-app-status-bar-style" content="default" />
<meta name="apple-mobile-web-app-title" content="ShortName" />
```

**Required in every manifest:** `name`, `short_name`, `description`,
`start_url`, `scope`, `display: standalone`, `orientation: portrait`,
`background_color`, `theme_color`, `categories`, and icons at **192 and 512
PNG plus a maskable copy**.

Liberty's `manifest.ts` states the reason plainly and it is the house
position: the 192 and 512 PNGs are not decoration — Chrome's installability
criteria require them and an SVG does not satisfy them, and without a
`maskable` copy Android letterboxes the mark onto a white tile next to every
other app on the phone.

> **Rule:** never ship an icon set by hand. Generate it from one SVG source
> (see §2 of Part 2). Icons are opaque, full-bleed RGB PNGs — no alpha, no
> ground band, no hand-edited PNGs.

### 2. Phone-first geometry: `dvh`, `viewport-fit=cover`, and safe areas

All five use `100dvh` and `env(safe-area-inset-*)`. This is the single most
consistent technical signature across the codebases, and Forest's stylesheet
carries a ~25-line comment about the one time it went wrong.

The rules that fell out of that:

- The page paints **under** the status bar and home indicator
  (`viewport-fit=cover`). Reserve the strips with `env(safe-area-inset-*)`,
  never with a hard-coded number.
- Put the inset behind a variable (`--safe-b: env(safe-area-inset-bottom, 0px)`)
  so every bottom-anchored element derives from **one** number, and so you can
  fake a notch in a desktop browser while testing.
- Use `min-height: 100dvh`, not `100vh`.
- The authoritative background belongs on `html` (or a dedicated
  `position: fixed` overshooting `#bg-fill` element), never on `body` alone —
  the safe-area strips paint from the root element, and a background on `body`
  leaves a visible band at the top on iOS.
- `html { overflow-x: hidden }` on the **document**, not just body: one
  overflowing child otherwise drags the whole page sideways and takes the
  fixed bottom nav with it, which reads as the navigation breaking.
- Touch targets are **≥44px**. Liberty spells out the reason in `ui.tsx`:
  *"thumbs, not cursors."*

### 3. One shell, everywhere: topbar → views → bottom tab bar

Four of the five vanilla/React apps use literally the same class names, and
the fifth (Liberty) uses the same structure under Tailwind. Reuse the
vocabulary rather than inventing new names:

| Element | Class | Notes |
|---|---|---|
| Fixed header | `.topbar` | Brand mark left, actions right |
| Bottom nav | `.tabbar` > `.tabbar-inner` > `.tab` | `.tab-icon` + `.tab-label` inside each |
| A screen | `.view` (or `.screen`) | Exactly one carries `.active` |
| Modal | `.overlay` + `.sheet` | Bottom sheet, backdrop, close button, Esc to dismiss |
| Small buttons | `.btn`, `.btn-primary`, `.icon-btn`, `.ghost-btn` | |
| Pills / filters | `.chip` | |
| Surfaces | `.card`, `.panel` | |
| Nothing-here state | `.empty-state` + `.empty-title` + `.empty-sub` | |
| Transient message | `.toast` | |

Naming is flat kebab-case with a component prefix (`detail-sheet`,
`seed-toolbar`, `db-tile-name`) — prefix-noun-modifier, **not** BEM, no CSS
modules, no utility framework outside Liberty. Tab switching is driven by a
`data-view` attribute on the button, resolved to `#view-<name>`.

### 4. Colour lives in `:root` as named tokens, and the palette is small

Every app defines its entire palette as CSS custom properties at the top of
its stylesheet, with a comment naming the *concept*: "classic popcorn box —
cinema red, warm white, butter & popcorn yellow"; "calm, minimalist focus app
… soft, low-contrast palette"; Liberty's "five colours: black, white, silver,
gold, parchment. Nothing else carries brand weight."

The rules:

- **Name tokens by role, not by hue** where the role can outlive the colour.
  Liberty's `--accent` is "the ink you press" — near-black on white, silver on
  black — and the comment notes the token *used to* be named after a colour
  and the name outlived it.
- Keep a **tight core** (roughly 5–8 brand-weight colours) and use anything
  beyond that semantically only. Red and green mean yes/no, never brand.
- Always define: surface ramp (`--bg`/`--paper`, raised, sunken), ink ramp
  (`--ink`, `--ink-soft`, `--ink-faint`), `--line`/`--line-strong`, one accent,
  `--radius`, and a shadow scale.
- **Write down why a colour exists** when it is non-obvious. Liberty's
  parchment token carries a paragraph about the narrow band of warmth it has
  to live in; that comment is the reason the next session does not retune it
  into a highlighter.

Multi-theme is done with `[data-theme="..."]` blocks that redefine the same
token names (SlotMachine ships five: vegas, cozy, neon, forest, red-carpet),
with the theme applied by an inline `<script>` in `<head>` **before first
paint** so there is no flash.

### 5. The user's data is theirs, on their device

Namespaced, versioned `localStorage` key: `popcorn:v1`, `luckyGoldSlots:v1`.
Bump the version and add a migration when the shape changes incompatibly —
Forest carries live migrations for five prior versions of its store.

Every read and write is wrapped: guard for no `window` (SSR), `try/catch`
around access, reads fall back to a default, writes silently no-op. Clash's
`storage.ts` explains it: a disabled store (private mode), a quota error, or
corrupt data must never be able to crash the app.

### 6. Works offline, updates itself

Service worker, network-first for same-origin GETs, falling back to cache,
falling back to `index.html`. `skipWaiting()` + `clients.claim()` so a bad
worker can be replaced by the next deploy instead of waiting for every tab in
the world to close. Bump `CACHE` on deploy; the `activate` handler deletes
every other cache.

Two standing exceptions worth copying:

- **Do not precache large assets.** Popcorn deliberately leaves its ~11MB
  lookup tier out of the shell; Forest leaves ~15MB of music out. The fetch
  handler caches them on first real use anyway. Precaching them would make
  every install pay for them.
- **A reading app may cache almost nothing.** Liberty's worker caches exactly
  one file and says so: *"that restraint is the design rather than laziness"* —
  a shell-caching worker will eventually pin someone to a stale build, and
  Liberty's whole value is that the bill in front of you is the current one.

### 7. No tracking, no ads, no dark patterns

Zero analytics, tag managers, session recorders or error-reporting SaaS in any
of the five. The only third-party origins any app touches are
`fonts.googleapis.com`/`fonts.gstatic.com` and, in Popcorn, TMDB attribution.

This is a product stance as much as a technical one, and it shows in the
copy: SlotMachine's own meta description is *"a healthier alternative to
predatory slot games — no microtransactions, no manipulation."* Forest is an
anti-screen-time app. Liberty is civic infrastructure. Build accordingly.

### 8. Dependencies are close to zero, and the test runner is `node --test`

- The three static apps (Forest, Popcorn, SlotMachine) have **no
  `package.json` at all**: no build step, no framework, no bundler. Plain
  HTML/CSS/JS served as files.
- The two TypeScript apps are still lean: Liberty ships 8 runtime deps
  (Next, React, Drizzle, postgres, zod, cuid2), Clash ships 4 (React,
  react-dom, pixi.js, workspace shared).
- Where there are tests, they run on **Node's built-in test runner** — Liberty
  via `node --import tsx --test`, Clash via `node --test
  --experimental-strip-types`. No Jest, no Vitest, no Playwright in
  `devDependencies`.
- Where a build-time tool is needed (Popcorn's TMDB fetcher, Forest's icon
  builder) it is plain Node in `scripts/`, dependency-free, and never ships to
  the browser.

> **Corollary rule:** if a new app does not need a server or a database, it
> gets no *runtime* dependencies and no build step. Reach for Next.js only
> when there is a real backend (Liberty: Postgres + ingestion) and Vite+React
> only when there is real client state to manage (Clash: a game engine).

**Refined 2026-08-20.** The original form of this rule was "no `package.json`
at all", which is what the three static apps do. That was tightened after it
collided with the test decision below: a `package.json` carrying *only*
`devDependencies` adds no runtime dependency, ships nothing to the browser,
and introduces no build step — and it pins the test runner and the icon
builder instead of leaving them to an ad-hoc `npm i -D` that silently stops
working a year later (Forest's `build-icons.js` has exactly that problem
today). The rule is therefore **no runtime dependencies**, not no manifest.

### 9. Pure functions at the edges, so the fiddly bits are testable

The clearest recurring architectural move. Liberty's `installPrompt.ts` says
it outright: platform detection across iOS, iPadOS, Android and half a dozen
embedded browsers *"is fiddly and impossible to check by hand — as a table it
is a unit test that runs in milliseconds."*

So: take a snapshot of the messy world (`{userAgent, isStandalone,
hasNativePrompt, maxTouchPoints, installed}`), pass it to a pure function,
get back an enum. Keep the DOM wiring in a separate layer. Popcorn's
`install.js` reimplements exactly the same table in vanilla JS. Same idea in
Liberty's `domain.ts`, `districts.ts`, `recurrence.ts`, and Clash's whole
`packages/shared` rules engine.

Where behaviour has to fail safe, say so in the code: the in-app-browser list
*"will go stale, and it is built to fail safe: an unrecognised embedded
browser falls through to the ordinary platform answer, so the worst case is a
less helpful message rather than a broken one."*

### 10. Comments explain *why*, and they are allowed to be long

This is the strongest stylistic signature in the whole set, and it is
non-negotiable house style. Comments in these repos are not restatements of
the code — they are the record of what was tried, what broke, and what must
not be undone. Examples that would be deleted by most style guides and should
not be here:

- 25 lines on why the Forest background lives on a fixed overshooting element
  rather than `background-attachment: fixed` (pixel-sampled from a real iOS
  screenshot).
- A paragraph on why Liberty's service worker caches one file.
- A paragraph on why Popcorn hides every `:hover` rule behind a media query
  (Safari sticks `:hover` to the last-tapped element, so the *next* card
  rendered into that slot inherited the highlight).
- Four numbered rules a new Forest sound effect has to keep, with the dBFS
  levels each was measured at.

Rule of thumb: **if a future session could plausibly "clean this up" and
reintroduce a bug, write the paragraph.**

### 10b. The accessibility floor — settled 2026-08-20

Promoted from the review queue. Three things every app gets:

- **`prefers-reduced-motion`.** The house pattern is Forest's inverted form —
  put animation inside `@media (prefers-reduced-motion: no-preference)` so
  motion is opt-in. The kit ships the blanket kill-switch instead, because
  that is the form that retrofits safely onto code that already animates.
- **`:focus-visible`.** Liberty's version: a 2px outline with
  `outline-offset`, applied through `:where(…)` so specificity stays at zero
  and any component can still override it.
- **`@media (hover: hover)` around every hover rule.** Adopted despite being
  1-of-5, because the bug it prevents would hit any of the others: on iOS
  Safari `:hover` sticks to the last-tapped element, so the next element
  rendered into that slot inherits a highlight it never earned. Keeping every
  hover rule in one guarded block makes it structurally impossible rather
  than something to remember.

`user-select` stays conditional rather than universal: apps you tap turn it
off with inputs and long-form text opting back in; apps you read leave it on.
Fonts default to the system stack, with `--font-display` as the one hook —
reach for a webfont only when the typeface is doing identity work.

### 11. Every app carries its own operating manual

`README.md` for the mission and the architecture; `CLAUDE.md` for *where
development actually stands*. The split is stated explicitly at the top of
Popcorn's: "Read README.md first for the app's mission — this file tracks
where development actually stands."

Both files are required as of 2026-08-20 (SlotMachine, which has neither, is
the gap to close). The kit ships a template for each.

`CLAUDE.md` reliably contains: a file map, invariants ("do not break these"),
conventions, testing notes, deploy notes, known gaps, and next steps ordered
by leverage. Liberty adds the best idea in the set — a **"Waiting on a human"**
checklist of everything blocked on a credential, a download, or a judgement
call that an agent cannot do from a sandbox.

### 12. A committed smoke test — added 2026-08-20

Every app gets `test/smoke.mjs` and `npm test`. This is the one rule here that
none of the five apps followed; it was added because the gap was the clearest
finding of the whole review. The three static apps have no test of any kind,
and Popcorn's own notes admit the recommendation engine has "no regression
safety net."

The bar is deliberately low and deliberately fixed. The smoke test does not
test app logic — it tests that **the shell still works**: the app boots, one
view is active, tabs switch, the sheet opens and closes on Escape, the worker
activates, saved state survives corrupt and future-version and
wrong-shaped data, and nothing throws. Those are what break when you touch CSS
or move a file, and they are exactly what nobody thinks to re-check by hand.

Two properties it must keep:

- **It serves the app itself on a random port**, so there is nothing to start
  first and no port to collide with.
- **Every assertion must be able to fail.** The first draft asserted that the
  tab bar's bottom edge equalled the viewport height — which, for a
  `position: fixed; bottom: 0` element, is true by construction whatever else
  is broken. It read like a geometry test and could never fail. It was
  replaced with one that makes the page tall, scrolls to the bottom, and
  checks the last line of content clears the bar. **An assertion that cannot
  fail is worse than no assertion, because it buys confidence it has not
  earned.**

Verified against five deliberately introduced regressions: a container losing
its bottom padding, the store losing its corrupt-JSON guard, a tab switch
leaving the old view active, a deleted `--safe-b` token, and a broken service
worker path. All five fail loudly and exit non-zero.

### 13. One apex domain, one subdomain per app

`forest.`, `popcorn.`, `slotmachine.`, `clashofhistory.`, `liberty.` — all on
`thewizardofoza.com`, DNS at the registrar (Hostinger), each app CNAME'd to
whatever host suits it. Cloudflare Pages is the default for static; GitHub
Pages and Vercel both appear; Clash's server is on Fly.io.

The rule that matters is in Liberty's README: **the choice of host must not
require moving the domain's nameservers**, because other apps share the
domain. Adding a subdomain is a single CNAME and touches nothing else.

Deploy runbooks live in `DEPLOY.md` (Popcorn, Clash) or a `## Deploying`
section of the README (Forest, Liberty).

---

## Part 2 — The starter kit

`starter-kit/` in this repo is a complete, working, zero-dependency PWA that
already obeys every rule in Part 1. Copy it, rename it, and you are past all
the plumbing.

```
starter-kit/
  index.html              shell: head tags, topbar, views, tabbar, sheet, toast
  manifest.webmanifest    every required field, marked TODO where app-specific
  sw.js                   network-first worker, shell list, cache versioning
  css/tokens.css          the token contract — the ONE file you retheme
  css/base.css            reset, safe areas, dvh, reduced motion, focus rings
  css/components.css      topbar, tabbar, view, sheet, btn, chip, card, toast…
  js/store.js             namespaced+versioned localStorage with migrations
  js/install.js           the install-prompt table, portable, app-name-driven
  js/ui.js                view switching, sheets, toasts, tab wiring
  js/app.js               where your app actually starts
  icons/build-icons.js    one SVG in → full icon set out
  test/smoke.mjs          shell regression test; serves the app itself
  package.json            dev-only — pins the test runner and icon builder
  scripts/new-app.sh      scaffold a renamed copy in one command
  README.md.template      mission + architecture skeleton
  CLAUDE.md.template      the operating-manual skeleton
```

**To start a new app:**

```bash
starter-kit/scripts/new-app.sh ../myapp "My App" myapp "#RRGGBB"
cd ../myapp && npm install && npm test
```

That copies the kit, rewrites the app name / short name / storage namespace /
theme colour everywhere they appear, promotes both doc templates into real
files, and leaves you with something that already installs to a home screen,
works offline, and passes 22 shell checks before you have written a line.

The three highest-leverage pieces, in order:

1. **`js/install.js`** — Liberty and Popcorn independently reimplemented the
   same four-outcome table (`android-prompt` / `ios-instructions` /
   `in-app-browser` / `none`), including the same embedded-browser signature
   list and the same "a dead button is worse than no button" reasoning. It
   is now written once, driven by config, and never needs writing again.
2. **`css/tokens.css` + `css/base.css`** — everything in rule §2 and §4 that
   cost Forest and Liberty real debugging time is already correct here.
3. **`icons/build-icons.js`** — generalised from Forest's. Point it at one
   SVG and it emits the full opaque, full-bleed, maskable-inclusive set that
   Chrome and Android actually require.

---

## Part 3 — The review queue

Patterns found in three or four of the five apps, not all. Listed with who
does and who doesn't.

### Decided 2026-08-20

| Item | Decision |
|---|---|
| `prefers-reduced-motion` | **Adopted** — now rule 10b |
| `:focus-visible` | **Adopted** — now rule 10b |
| `@media (hover: hover)` guard | **Adopted** — now rule 10b |
| `README.md` + `CLAUDE.md` | **Adopted** — now rule 11, both templates ship |
| `user-select` | **Conditional** — tap apps off, reading apps on |
| Webfonts | **System stack by default**, webfont only for identity work |
| Install-prompt UI | **Ships by default** in the kit; delete the button per app |
| Service-worker strategy | **Network-first** is the house default |
| ES modules vs script tags | **ES modules** — no build step, must be served over http |
| Error visibility | **Committed smoke test** — now rule 12. No telemetry adopted |

### Still open

**Should Clash get a service worker?** It ships a manifest and full install
support but no worker, so it is installable and not offline-capable. This is
a question about an existing app rather than about the kit, so it was left out
of the kit decisions.

**Is there a middle path on telemetry?** The smoke test closes the CI half of
the feedback gap. The field half is still open: a crash on some Android WebView
is invisible forever, and you cannot tell a broken feature from an unused one.
A self-hosted, no-cookie, no-identifier error endpoint would violate none of
the stated principles. Deliberately not adopted — noting it so the decision
stays a decision rather than an oversight.

---

The original review notes follow, kept for the reasoning behind each call.

### 3a. `prefers-reduced-motion` — 4 of 5

**Has it:** Liberty, Forest, Popcorn, Clash. **Missing:** SlotMachine.

Two different implementations even among the four: Popcorn and Liberty use
the blanket `*, *::before, *::after { animation-duration: 0.01ms !important }`
kill switch; Forest inverts it and only *adds* animation inside
`@media (prefers-reduced-motion: no-preference)`. SlotMachine is the most
animation-heavy app in the set and has no handling at all.

*My read: this should be promoted to a rule, with Forest's inverted form as
the house pattern. The kit ships the blanket version because it is safer to
retrofit.*

### 3b. `:focus-visible` styling — 3 of 5

**Has it:** Liberty, Popcorn, Clash. **Missing:** Forest, SlotMachine.

Liberty's is the good one — `2px solid var(--gold-bright)` with
`outline-offset: 2px`, applied via `:where(a, button, input, textarea, select,
[tabindex])` so specificity stays at zero.

*My read: promote. It is four lines and it is the difference between
keyboard-usable and not. The kit includes Liberty's version.*

### 3c. Install prompt UI — 3 of 5

**Has it:** Liberty, Popcorn, Clash. **Missing:** Forest, SlotMachine.

All five are *installable*; only three ever offer. Forest instead ships an
Android APK wrapper (Capacitor, built in CI). SlotMachine relies entirely on
the browser's own affordance.

*My read: needs your call, because it is a product question, not a technical
one. If most traffic arrives from a shared link, the offer is worth a lot; if
people find the app once and keep it, the browser's own prompt is enough.*

### 3d. `user-select: none` on `body`, with inputs opting back in — 4 of 5

**Has it:** Forest, Popcorn, SlotMachine, Clash. **Missing:** Liberty.

Both stated reasons are good and they conflict, which is why this is here
rather than in Part 1. Clash: *"This is a game, not a document."* Popcorn:
*"This is a tap-driven app, not a document."* Liberty is genuinely a
*reading* tool, so selection has to work.

*My read: keep it conditional. Rule should be "apps you tap: off, with
`input, textarea` and any long-form text opting back in. Apps you read: on."
Note Popcorn already carves out `.detail-title` because copying an exact
movie title to paste into a streaming search is a real thing people do.*

### 3e. Local-first, no server — 4 of 5

**Has it:** Forest, Popcorn, SlotMachine, Clash (client state).
**Different:** Liberty (Postgres + nightly ingestion; only the install flag is
local).

*My read: this is a consequence of what each app is, not a preference to
enforce. Worth stating as a default though: "no server until the data
genuinely cannot live on the device."*

### 3f. Service worker — 4 of 5

**Has it:** Liberty, Forest, Popcorn, SlotMachine. **Missing:** Clash.

Clash ships a manifest and full install support but no worker, so it is
installable and not offline-capable. Also note SlotMachine's worker is
**cache-first** (stale-while-revalidate) while Forest's and Popcorn's are
**network-first** — a real behavioural difference in how fast a deploy
reaches users.

*My read: two things to rule on — whether Clash should get one, and whether
network-first is the house default. The kit uses network-first, matching the
majority.*

### 3g. `README.md` and `CLAUDE.md` — 4 of 5

**Has both:** Liberty, Forest, Popcorn, Clash (plus `AGENTS.md` and
`RULES.md`). **Has neither:** SlotMachine.

*My read: promote to a rule; SlotMachine is simply the gap. The kit ships a
`CLAUDE.md.template`.*

### 3h. A Google-hosted display font — 2 of 5 (noting it as the low end)

**Has it:** Forest (Nunito, used for body), Clash (Cinzel, headings only).
**System stack only:** Liberty, Popcorn, SlotMachine.

Below your 3–4 threshold, but flagging it because it is the only third-party
runtime request any of these apps make, which sits oddly against §7. Both
apps that use one `preconnect` to both font origins first.

*My read: default to a system stack with `--font-display` as the one hook.
Reach for a webfont only when the typeface is doing identity work — as Cinzel
is for Clash.*

### 3i. `@media (hover: hover)` guard on hover styles — 1 of 5

**Has it:** Popcorn only.

Listed despite being 1/5 because the bug it fixes is real and would hit any
of the others: on iOS Safari, `:hover` sticks to the last-tapped element, so a
newly rendered card in the same slot inherits the highlight. Popcorn keeps
*every* `:hover` rule in one `@media (hover: hover)` block.

*My read: cheap insurance, worth adopting. The kit does it.*

---

## Quick reference — the checklist

```
[ ] manifest: standalone, portrait, 192+512 PNG, maskable copy, categories
[ ] head: viewport-fit=cover, theme-color, apple-* tags, apple-touch-icon
[ ] 100dvh + env(safe-area-inset-*) behind a variable; bg on <html>
[ ] html { overflow-x: hidden }; touch targets >= 44px
[ ] .topbar / .view.active / .tabbar shell, data-view switching
[ ] palette as :root tokens, named by role, commented where non-obvious
[ ] localStorage key "<app>:v1", guarded accessors, migration on bump
[ ] service worker: network-first, skipWaiting + claim, no huge precache
[ ] zero analytics / ads / third-party runtime services
[ ] no package.json unless there is a real server or real client state
[ ] messy platform logic behind a pure function over a snapshot
[ ] comments explain why; write the paragraph if a cleanup could regress it
[ ] README.md (mission + architecture) and CLAUDE.md (state of play)
[ ] prefers-reduced-motion, :focus-visible, hover rules behind (hover: hover)
[ ] npm test green — and every assertion in it can actually fail
[ ] one subdomain, one CNAME, nameservers untouched
```
