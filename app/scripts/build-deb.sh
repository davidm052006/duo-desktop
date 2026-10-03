#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
PACKAGING_DIR="$APP_ROOT/packaging/linux"
BUILD_BUNDLE="$APP_ROOT/build/linux/x64/release/bundle"
DIST_DIR="$APP_ROOT/dist"
STAGING_DIR="$APP_ROOT/build/linux-deb"
PACKAGE_ROOT="$STAGING_DIR/root"

usage() {
  cat <<'USAGE'
Usage: scripts/build-deb.sh [--skip-build]

By default the script builds the Flutter Linux release bundle first.
Use --skip-build to package an existing build/linux/x64/release/bundle.
USAGE
}

SKIP_BUILD=0
case "${1:-}" in
  "") ;;
  --skip-build) SKIP_BUILD=1 ;;
  -h|--help) usage; exit 0 ;;
  *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
esac

for command in awk sed install find dpkg-deb; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "Required command not found: $command" >&2
    exit 1
  }
done

PUBSPEC="$APP_ROOT/pubspec.yaml"
VERSION_FULL="$(awk '/^version:[[:space:]]*/ {print $2; exit}' "$PUBSPEC")"
if [[ ! "$VERSION_FULL" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]]; then
  echo "Unsupported or missing pubspec version: ${VERSION_FULL:-<empty>}" >&2
  echo "Expected X.Y.Z+N" >&2
  exit 1
fi
VERSION="${VERSION_FULL%%+*}"
PACKAGE_NAME="duo-desktop_${VERSION}_amd64.deb"
PACKAGE_PATH="$DIST_DIR/$PACKAGE_NAME"

CEF_COMMON="$APP_ROOT/packages/webview_cef_duo/common"
CEF_LINUX="$APP_ROOT/packages/webview_cef_duo/linux"
if grep -RInE -- '--no-sandbox|--disable-web-security|--allow-running-insecure-content|--ignore-certificate-errors' "$CEF_COMMON" "$CEF_LINUX"; then
  echo "Refusing to package: insecure Chromium/CEF switch found." >&2
  exit 1
fi
if grep -RInE 'cefs\.no_sandbox[[:space:]]*=[[:space:]]*true' "$CEF_COMMON" "$CEF_LINUX"; then
  echo "Refusing to package: CEF sandbox is disabled in source." >&2
  exit 1
fi
if ! grep -RInE 'cefs\.no_sandbox[[:space:]]*=[[:space:]]*false' "$CEF_COMMON" >/dev/null; then
  echo "Refusing to package: expected cefs.no_sandbox = false was not found." >&2
  exit 1
fi

if (( SKIP_BUILD == 0 )); then
  (
    cd "$APP_ROOT"
    flutter build linux --release
  )
fi

if [[ ! -x "$BUILD_BUNDLE/duo_desktop" ]]; then
  echo "Release bundle missing executable: $BUILD_BUNDLE/duo_desktop" >&2
  exit 1
fi

required_paths=(
  "data/flutter_assets"
  "lib/libcef.so"
  "lib/chrome-sandbox"
  "lib/locales"
  "lib/icudtl.dat"
  "lib/v8_context_snapshot.bin"
)
for relative_path in "${required_paths[@]}"; do
  if [[ ! -e "$BUILD_BUNDLE/$relative_path" ]]; then
    echo "Release bundle is missing required CEF/Flutter asset: $relative_path" >&2
    exit 1
  fi
done

rm -rf "$STAGING_DIR"
mkdir -p \
  "$PACKAGE_ROOT/DEBIAN" \
  "$PACKAGE_ROOT/usr/bin" \
  "$PACKAGE_ROOT/usr/lib/duo-desktop" \
  "$PACKAGE_ROOT/usr/share/applications" \
  "$PACKAGE_ROOT/usr/share/icons/hicolor/scalable/apps" \
  "$DIST_DIR"
chmod 0755 "$PACKAGE_ROOT/DEBIAN"

cp -a "$BUILD_BUNDLE/." "$PACKAGE_ROOT/usr/lib/duo-desktop/"

cat > "$PACKAGE_ROOT/usr/bin/duo-desktop" <<'LAUNCHER'
#!/usr/bin/env bash
set -e
exec /usr/lib/duo-desktop/duo_desktop "$@"
LAUNCHER
chmod 0755 "$PACKAGE_ROOT/usr/bin/duo-desktop"

install -m 0644 "$PACKAGING_DIR/duo-desktop.desktop" \
  "$PACKAGE_ROOT/usr/share/applications/duo-desktop.desktop"
install -m 0644 "$PACKAGING_DIR/icons/duo-desktop.svg" \
  "$PACKAGE_ROOT/usr/share/icons/hicolor/scalable/apps/duo-desktop.svg"

chmod 4755 "$PACKAGE_ROOT/usr/lib/duo-desktop/lib/chrome-sandbox"

sed "s/@VERSION@/$VERSION_FULL/g" \
  "$PACKAGING_DIR/DEBIAN/control.in" > "$PACKAGE_ROOT/DEBIAN/control"
chmod 0644 "$PACKAGE_ROOT/DEBIAN/control"

if [[ -n "${SOURCE_DATE_EPOCH:-}" ]]; then
  find "$PACKAGE_ROOT" -print0 | xargs -0 touch --no-dereference --date="@$SOURCE_DATE_EPOCH"
fi

rm -f "$PACKAGE_PATH"
dpkg-deb --root-owner-group --build "$PACKAGE_ROOT" "$PACKAGE_PATH"

echo "Created: $PACKAGE_PATH"
echo "Version: $VERSION_FULL"
echo "Inspect with: dpkg-deb -I '$PACKAGE_PATH' && dpkg-deb -c '$PACKAGE_PATH'"
