#!/usr/bin/env bash
#
# Scaffold a new app from the starter kit.
#
#   starter-kit/scripts/new-app.sh <dest> <"App Name"> <slug> <#themecolor> [<"Short Name">]
#
# Example:
#   starter-kit/scripts/new-app.sh ../aquarium "Aquarium" aquarium "#0b3d5c"
#
# Copies the kit, rewrites every placeholder, and leaves you with something
# that already installs to a home screen and works offline.

set -euo pipefail

if [ "$#" -lt 4 ]; then
  sed -n '3,12p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
fi

DEST="$1"
APP_NAME="$2"
APP_SLUG="$3"
THEME_COLOR="$4"
APP_SHORT="${5:-$APP_NAME}"

KIT="$(cd "$(dirname "$0")/.." && pwd)"

if [ -e "$DEST" ]; then
  echo "error: $DEST already exists — refusing to overwrite." >&2
  exit 1
fi

mkdir -p "$DEST"
# Copy everything except this scaffolder itself.
(cd "$KIT" && tar --exclude='scripts/new-app.sh' -cf - .) | (cd "$DEST" && tar -xf -)
rmdir "$DEST/scripts" 2>/dev/null || true

# The kit's own README describes the kit, not the new app — drop it, then
# promote the two templates into the real files.
rm -f "$DEST/README.md"
for t in CLAUDE README; do
  if [ -f "$DEST/$t.md.template" ]; then
    mv "$DEST/$t.md.template" "$DEST/$t.md"
  fi
done

# Substitution runs through node, NOT sed, and that is deliberate.
#
# sed's replacement text is not literal: `&` expands to the whole match, `\`
# escapes, and the delimiter (whatever you pick) terminates the expression. So
# an app called "Fish & Chips" came out as "Fish __APP_NAME__ Chips", a name
# containing a backslash silently lost it, and one containing the delimiter
# killed the script outright. All three were real, all three were found by
# trying them.
#
# Escaping the replacement by hand would fix it and would be exactly the kind
# of fiddly, untestable string juggling this codebase avoids elsewhere.
# node's split/join has no pattern semantics at all — every byte is literal —
# so the whole class of bug stops existing. node is already required by
# `npm test` and `npm run icons`, so this adds no new tool.
if ! command -v node >/dev/null 2>&1; then
  echo "error: node is required to scaffold (it does the literal text substitution)." >&2
  exit 1
fi

node - "$DEST" \
  __APP_NAME__         "$APP_NAME" \
  __APP_SHORT_NAME__   "$APP_SHORT" \
  __APP_SLUG__         "$APP_SLUG" \
  __THEME_COLOR__      "$THEME_COLOR" \
  __APP_TAGLINE__      "TODO: one line, what it is" \
  __APP_DESCRIPTION__  "TODO: one sentence, what it does for you" <<'NODE'
const fs = require("fs");
const path = require("path");

const [dest, ...rest] = process.argv.slice(2);
const pairs = [];
for (let i = 0; i < rest.length; i += 2) pairs.push([rest[i], rest[i + 1]]);

const EXTS = new Set([".html", ".css", ".js", ".mjs", ".webmanifest", ".json", ".md"]);

/*
 * A name is not one string — it is a different string in each destination.
 * `Say "Hi"` dropped verbatim into manifest.webmanifest produces invalid JSON,
 * and into install.js produces invalid JavaScript. Both fail SILENTLY: an
 * unparseable manifest is ignored by the browser, so the app simply stops
 * being installable with nothing on the console to say why. That is the worst
 * kind of bug this scaffolder could ship, so the value is escaped for the
 * syntax it is landing in.
 */
const escapers = {
  // JSON string body — also correct for a JS string literal.
  json: (v) => JSON.stringify(v).slice(1, -1),
  // Text content and double-quoted attribute values are both safe with these.
  html: (v) => v.replace(/&/g, "&amp;").replace(/</g, "&lt;")
                .replace(/>/g, "&gt;").replace(/"/g, "&quot;"),
  raw: (v) => v,
};

function escaperFor(ext) {
  if (ext === ".json" || ext === ".webmanifest" || ext === ".js" || ext === ".mjs") return escapers.json;
  if (ext === ".html") return escapers.html;
  return escapers.raw;   // .md, .css — prose and stylesheets take it literally
}

function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) { walk(full); continue; }
    const ext = path.extname(entry.name);
    if (!EXTS.has(ext)) continue;
    const escape = escaperFor(ext);
    let text = fs.readFileSync(full, "utf8");
    // split/join, not replace(): every byte of the replacement is literal.
    for (const [token, value] of pairs) text = text.split(token).join(escape(value));
    fs.writeFileSync(full, text);
  }
}
walk(dest);

/*
 * Verify the output rather than trusting it — the same reasoning as
 * build-icons.js byte-checking that a PNG came out opaque. Escaping is easy to
 * get subtly wrong and the failures are invisible, so parse what was actually
 * written and refuse to hand over a broken scaffold.
 */
const problems = [];
for (const rel of ["manifest.webmanifest", "package.json"]) {
  const full = path.join(dest, rel);
  if (!fs.existsSync(full)) continue;
  try { JSON.parse(fs.readFileSync(full, "utf8")); }
  catch (err) { problems.push(`${rel}: ${err.message}`); }
}
/*
 * `node --check`, not vm.Script. The kit's js/ is ES modules, and vm.Script
 * parses its input as a classic script — so `export` is a SyntaxError there no
 * matter what the app is called, which made the first version of this check
 * reject every scaffold including "Aquarium". `--check` resolves the parse
 * goal the same way the runtime does, honouring "type": "module" in the
 * package.json just written above.
 */
const { spawnSync } = require("child_process");
for (const rel of ["js/app.js", "js/install.js", "js/store.js", "js/ui.js", "sw.js"]) {
  const full = path.join(dest, rel);
  if (!fs.existsSync(full)) continue;
  const res = spawnSync(process.execPath, ["--check", full], { encoding: "utf8" });
  if (res.status !== 0) {
    const line = (res.stderr || "").split("\n").find((l) => /Error/.test(l)) || "did not parse";
    problems.push(`${rel}: ${line.trim()}`);
  }
}
if (problems.length) {
  console.error("\nScaffold produced files that do not parse:\n" +
    problems.map((p) => "  " + p).join("\n") +
    "\n\nThis is a bug in new-app.sh, not in your app name. Nothing was left behind.");
  fs.rmSync(dest, { recursive: true, force: true });
  process.exit(1);
}
NODE

cat <<DONE

  $APP_NAME scaffolded in $DEST

  Next:
    1. npm install           — dev tools only; nothing ships to the browser
    2. icons/source.svg      — draw the mark, then: npm run icons
    3. css/tokens.css        — the palette. This is the file you retheme.
    4. manifest.webmanifest  — fill the TODO tagline/description, pick categories
    5. index.html            — the TODO description, and the real tabs
    6. README.md / CLAUDE.md — the mission, then the file map and invariants

  Serve it:  cd $DEST && npm run serve
  Test it:   cd $DEST && npm test

  Deploy: Cloudflare Pages, framework preset None, build command empty,
  output directory /. Then one CNAME for $APP_SLUG.<your-domain> at the
  registrar. Nameservers do not move.

DONE
