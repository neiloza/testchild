# Starter kit

A complete, working, zero-dependency PWA that already obeys every rule in
[`../docs/APP_DESIGN_RULES.md`](../docs/APP_DESIGN_RULES.md). Copy it, rename
it, and you are past all the plumbing.

## Use it

```bash
starter-kit/scripts/new-app.sh ../myapp "My App" myapp "#16161a" "MyApp"
cd ../myapp
npm install     # dev tools only — nothing ships to the browser
npm test        # 22 shell checks, all green on a fresh scaffold
npm run serve   # http://localhost:8000
```

That rewrites the app name, short name, storage namespace and theme colour
everywhere they appear, turns `CLAUDE.md.template` into a real `CLAUDE.md`,
and leaves you with something that installs to a home screen and works
offline out of the box.

## What is in here

| Path | What it is |
|---|---|
| `index.html` | The shell — head tags, topbar, views, tabbar, install sheet, toast |
| `manifest.webmanifest` | Every field Chrome and Android actually require |
| `sw.js` | Network-first worker, shell list, cache versioning |
| `css/tokens.css` | **The one file you retheme.** Palette, shape, type, safe areas |
| `css/base.css` | Reset, page geometry, motion, focus rings |
| `css/components.css` | `.topbar` `.view` `.tabbar` `.sheet` `.btn` `.chip` `.card` `.toast`… |
| `js/store.js` | Namespaced + versioned `localStorage`, guarded, with migrations |
| `js/install.js` | The add-to-home-screen decision table, portable |
| `js/ui.js` | View switching, sheets, toasts |
| `js/app.js` | Where your app actually starts |
| `icons/build-icons.js` | One SVG in → the full icon set out |
| `test/smoke.mjs` | Shell regression test — serves the app itself, no setup |
| `package.json` | Dev-only. Pins the test runner and icon builder; no runtime deps |
| `README.md.template` | Mission + architecture skeleton |
| `CLAUDE.md.template` | The operating-manual skeleton |

## Order of work on a new app

1. **`icons/source.svg`** — draw the mark, then `node icons/build-icons.js`.
   The kit ships a **placeholder** icon set so a fresh scaffold has no 404s
   and installs correctly on day one. It is a generic star — replace it.
   Note the two rules in that script's header: everything full-bleed and
   opaque, and the maskable copy is not optional. Chrome's installability
   criteria require a 192 **and** a 512 PNG — an SVG does not satisfy them,
   and without both the install offer simply never appears.
2. **`css/tokens.css`** — the palette. Name tokens by role, keep the
   brand-weight set small, and write down why a colour exists if it is not
   obvious.
3. **`manifest.webmanifest`** — tagline, description, `categories`.
4. **`index.html`** — the description meta, and your real tabs.
5. **`js/store.js`** — `defaultState()` is the shape of a brand-new user.
6. **`CLAUDE.md`** — file map and invariants, while you still remember them.

## Things the kit decides for you, and where to change them

- **Network-first service worker.** Right for an app whose data is local.
  If the app's value is that what you are reading is *current*, cache far
  less — see the note at the top of `sw.js`.
- **`user-select: none` on `body`.** Right for a tap-driven app. Delete that
  block in `base.css` if you are building something to read.
- **Blanket reduced-motion kill switch.** The stricter house pattern is to
  invert it and put every animation inside
  `@media (prefers-reduced-motion: no-preference)`. Worth doing on a new app.
- **System font stack.** `--font-display` is the hook if the app needs a
  typeface doing identity work. A webfont is the only third-party request
  these apps make, so make it earn its place.
- **ES modules, not `<script>` tags.** Files declare what they need, so
  reordering cannot break the app. Still no build step — but the page must be
  served over http, so you can no longer just double-click `index.html`.
- **A dev-only `package.json`.** No runtime dependencies and no build step;
  it exists so the test runner and icon builder are pinned rather than
  installed ad hoc. The app itself is still just files.

## About the smoke test

`npm test` boots the app in a real browser and checks the shell: it loads with
one view active, tabs switch, the install sheet opens and closes on Escape,
the service worker activates, bottom content clears the tab bar, and saved
state survives corrupt, future-version and wrong-shaped data.

It does **not** test your app's logic — add those cases at the marked point in
`test/smoke.mjs`.

One rule if you extend it: **every assertion must be able to fail.** The first
draft of this file asserted that the tab bar's bottom edge equalled the
viewport height, which for a `position: fixed; bottom: 0` element is true by
construction no matter what is broken. It looked like a geometry check and
could never fail. Before you add an assertion, break the thing it covers and
watch it go red.
