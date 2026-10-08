#!/usr/bin/env bash
# Validates the exact files shipped to Linux users. This is deliberately run
# after all archive creation so a correct Flutter command cannot be followed by
# packaging an old/unconfigured bundle.
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 VERSION PACKAGE.deb PORTABLE.zip UPDATE.zip" >&2
  exit 2
fi

VERSION="$1"
DEB="$2"
PORTABLE="$3"
UPDATE="$4"

for command in dpkg-deb unzip grep cmp mktemp; do
  command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 1; }
done
for file in "$DEB" "$PORTABLE" "$UPDATE"; do
  [[ -f "$file" ]] || { echo "Missing release artifact: $file" >&2; exit 1; }
done

: "${DUO_PUBLIC_CLOUD_URL:?DUO_PUBLIC_CLOUD_URL is required}"
: "${DUO_PUBLIC_SUPABASE_URL:?DUO_PUBLIC_SUPABASE_URL is required}"
: "${DUO_PUBLIC_SUPABASE_PUBLISHABLE_KEY:?DUO_PUBLIC_SUPABASE_PUBLISHABLE_KEY is required}"

TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEMP_ROOT"' EXIT
dpkg-deb -x "$DEB" "$TEMP_ROOT/deb"
unzip -q "$PORTABLE" -d "$TEMP_ROOT/portable"
unzip -q "$UPDATE" -d "$TEMP_ROOT/update"

SEED="$TEMP_ROOT/deb/usr/lib/duo-desktop/seed"
DEB_APP="$SEED/versions/$VERSION/app"
PORTABLE_APP="$TEMP_ROOT/portable/versions/$VERSION/app"
UPDATE_APP="$TEMP_ROOT/update/app"

for path in \
  "$SEED/DuoLauncher" "$SEED/launcher-config.json" "$SEED/current.json" \
  "$DEB_APP/duo_desktop" "$DEB_APP/lib/libflutter_linux_gtk.so"; do
  [[ -f "$path" ]] || { echo "DEB seed missing $path" >&2; exit 1; }
done
[[ -f "$SEED/versions/$VERSION/service/DuoDesktop.Service" ]] || { echo "DEB seed missing local service" >&2; exit 1; }

for app in "$PORTABLE_APP" "$UPDATE_APP"; do
  [[ -f "$app/duo_desktop" && -f "$app/lib/libflutter_linux_gtk.so" ]] || { echo "Archive missing Flutter app at $app" >&2; exit 1; }
done
[[ -f "$TEMP_ROOT/portable/versions/$VERSION/service/DuoDesktop.Service" ]] || { echo "Portable missing local service" >&2; exit 1; }
[[ -f "$TEMP_ROOT/update/service/DuoDesktop.Service" ]] || { echo "Update missing local service" >&2; exit 1; }
[[ -f "$TEMP_ROOT/update/launcher/DuoLauncher" ]] || { echo "Update missing launcher" >&2; exit 1; }
[[ -f "$TEMP_ROOT/portable/DuoLauncher" && -f "$TEMP_ROOT/portable/launcher-config.json" && -f "$TEMP_ROOT/portable/current.json" ]] || { echo "Portable missing launcher metadata" >&2; exit 1; }

cmp "$DEB_APP/lib/libapp.so" "$PORTABLE_APP/lib/libapp.so"
cmp "$DEB_APP/lib/libapp.so" "$UPDATE_APP/lib/libapp.so"
for value in "$DUO_PUBLIC_CLOUD_URL" "$DUO_PUBLIC_SUPABASE_URL" "$DUO_PUBLIC_SUPABASE_PUBLISHABLE_KEY"; do
  # AOT data is not necessarily line-delimited, so inspect the binary rather
  # than relying on strings(1)'s line-oriented output.
  grep -aFq "$value" "$DEB_APP/lib/libapp.so" || { echo "Compiled Linux app is missing required public configuration" >&2; exit 1; }
done

grep -Fqx "{\"version\":\"$VERSION\"}" "$SEED/current.json" || { echo "Seed current.json does not select $VERSION" >&2; exit 1; }
echo "Linux artifacts verified: configured Flutter bundle is identical in DEB, portable, and update ZIP."
