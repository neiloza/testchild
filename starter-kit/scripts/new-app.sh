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

# CLAUDE.md.template becomes the real CLAUDE.md.
if [ -f "$DEST/CLAUDE.md.template" ]; then
  mv "$DEST/CLAUDE.md.template" "$DEST/CLAUDE.md"
fi
# The kit's own README describes the kit, not the new app.
rm -f "$DEST/README.md"

subst() {
  # macOS and GNU sed disagree about -i; write to a temp file instead.
  local f="$1"
  local tmp
  tmp="$(mktemp)"
  sed \
    -e "s|__APP_NAME__|${APP_NAME}|g" \
    -e "s|__APP_SHORT_NAME__|${APP_SHORT}|g" \
    -e "s|__APP_SLUG__|${APP_SLUG}|g" \
    -e "s|__THEME_COLOR__|${THEME_COLOR}|g" \
    -e "s|__APP_TAGLINE__|TODO: one line, what it is|g" \
    -e "s|__APP_DESCRIPTION__|TODO: one sentence, what it does for you|g" \
    "$f" > "$tmp"
  mv "$tmp" "$f"
}

while IFS= read -r -d '' f; do
  subst "$f"
done < <(find "$DEST" -type f \
  \( -name '*.html' -o -name '*.css' -o -name '*.js' -o -name '*.webmanifest' -o -name '*.md' \) -print0)

cat <<DONE

  $APP_NAME scaffolded in $DEST

  Next:
    1. icons/source.svg      — draw the mark, then: node icons/build-icons.js
    2. css/tokens.css        — the palette. This is the file you retheme.
    3. manifest.webmanifest  — fill the TODO tagline/description, pick categories
    4. index.html            — the TODO description, and the real tabs
    5. CLAUDE.md             — fill in the file map and the invariants

  Serve it:  python3 -m http.server 8000 --directory $DEST

  Deploy: Cloudflare Pages, framework preset None, build command empty,
  output directory /. Then one CNAME for $APP_SLUG.<your-domain> at the
  registrar. Nameservers do not move.

DONE
