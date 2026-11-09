#!/usr/bin/env bash
# Package a `flutter build macos` bundle into a drag-to-install DMG for one
# CPU architecture.
#
#   tool/package_macos_dmg.sh <Release|Profile|Debug> <arm64|x86_64> <output.dmg>
#
# Build the bundle for that architecture first, e.g.
#   FLUTTER_XCODE_ARCHS=arm64 flutter build macos --release
#
# Before packaging:
#   * every Mach-O file must contain the requested architecture. Prebuilt
#     universal binaries from plugins are thinned to it, so the DMG only
#     carries code that the target Mac can run;
#   * the bundle must carry a valid (ad-hoc or real) code signature. Thinning
#     breaks the bundle seal, so the bundle is then re-signed ad-hoc with its
#     entitlements preserved. Unsigned binaries cannot launch on Apple
#     Silicon at all.
set -euo pipefail

usage="usage: $0 <Release|Profile|Debug> <arm64|x86_64> <output.dmg>"
config="${1:?$usage}"
arch="${2:?$usage}"
out="${3:?$usage}"
app="build/macos/Build/Products/${config}/Neiroha.app"
volume_name="Neiroha"

case "$arch" in
  arm64 | x86_64) ;;
  *)
    echo "error: unsupported architecture '$arch'" >&2
    echo "$usage" >&2
    exit 2
    ;;
esac

if [[ ! -d "$app" ]]; then
  mode="$(echo "$config" | tr '[:upper:]' '[:lower:]')"
  echo "error: $app not found; run 'FLUTTER_XCODE_ARCHS=$arch flutter build macos --$mode' first" >&2
  exit 1
fi

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/Neiroha.app"
bundle="$staging/Neiroha.app"

# A dev run never writes state into the bundle on macOS (PathService uses
# Application Support), but guard against stray local data anyway.
rm -rf "$bundle/Contents/MacOS/neiroha_data" "$bundle/Contents/MacOS/voice_asset"

missing=0
thinned=0
while IFS= read -r -d '' f; do
  file -b "$f" | grep -q 'Mach-O' || continue
  rel="${f#"$staging"/}"
  archs="$(lipo -archs "$f" 2>/dev/null || true)"
  if [[ " $archs " != *" $arch "* ]]; then
    echo "error: no $arch slice (${archs:-unknown}): $rel" >&2
    missing=1
  elif [[ "$archs" != "$arch" ]]; then
    lipo "$f" -thin "$arch" -output "$f.thin"
    chmod "$(stat -f '%Lp' "$f")" "$f.thin"
    mv "$f.thin" "$f"
    echo "thinned ($archs -> $arch): $rel"
    thinned=$((thinned + 1))
  fi
done < <(find "$bundle" -type f \( -perm -u+x -o -name '*.dylib' \) -print0)
if [[ "$missing" == "1" ]]; then
  exit 1
fi
echo "All Mach-O files are $arch only ($thinned thinned)."

if [[ "$thinned" -gt 0 ]] || ! codesign --verify --deep --strict "$bundle" 2>/dev/null; then
  echo "Re-signing bundle ad-hoc."
  codesign --force --deep --sign - \
    --preserve-metadata=identifier,entitlements,flags "$bundle"
fi
codesign --verify --deep --strict "$bundle"
codesign -dv "$bundle" 2>&1 | grep -E '^(Identifier|Format|Signature)=' || true

ln -s /Applications "$staging/Applications"

mkdir -p "$(dirname "$out")"
hdiutil create \
  -volname "$volume_name" \
  -srcfolder "$staging" \
  -fs HFS+ \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  "$out"
hdiutil verify "$out"
echo "Created $out ($(du -h "$out" | cut -f1))"
