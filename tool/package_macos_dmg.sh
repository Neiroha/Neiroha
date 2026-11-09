#!/usr/bin/env bash
# Package a `flutter build macos` bundle into a drag-to-install DMG.
#
#   tool/package_macos_dmg.sh <Release|Profile|Debug> <output.dmg>
#
# Checks before packaging:
#   * every Mach-O file in the bundle contains both arm64 and x86_64, so the
#     one DMG runs on Apple Silicon and Intel Macs (skip with
#     ALLOW_THIN=1, e.g. for a local Debug build of the host arch only);
#   * the bundle carries a valid (ad-hoc or real) code signature. Unsigned
#     binaries cannot launch on Apple Silicon at all.
set -euo pipefail

config="${1:?usage: $0 <Release|Profile|Debug> <output.dmg>}"
out="${2:?usage: $0 <Release|Profile|Debug> <output.dmg>}"
app="build/macos/Build/Products/${config}/Neiroha.app"
volume_name="Neiroha"

if [[ ! -d "$app" ]]; then
  mode="$(echo "$config" | tr '[:upper:]' '[:lower:]')"
  echo "error: $app not found; run 'flutter build macos --$mode' first" >&2
  exit 1
fi

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/Neiroha.app"
bundle="$staging/Neiroha.app"

# A dev run never writes state into the bundle on macOS (PathService uses
# Application Support), but guard against stray local data anyway.
rm -rf "$bundle/Contents/MacOS/neiroha_data" "$bundle/Contents/MacOS/voice_asset"

if [[ "${ALLOW_THIN:-0}" != "1" ]]; then
  thin=0
  while IFS= read -r -d '' f; do
    if file -b "$f" | grep -q 'Mach-O'; then
      archs="$(lipo -archs "$f" 2>/dev/null || true)"
      if [[ " $archs " != *" arm64 "* || " $archs " != *" x86_64 "* ]]; then
        echo "error: not universal (${archs:-unknown}): ${f#"$staging"/}" >&2
        thin=1
      fi
    fi
  done < <(find "$bundle" -type f \( -perm -u+x -o -name '*.dylib' \) -print0)
  if [[ "$thin" == "1" ]]; then
    exit 1
  fi
  echo "All Mach-O files are universal (arm64 + x86_64)."
fi

if ! codesign --verify --deep --strict "$bundle" 2>/dev/null; then
  echo "Bundle signature invalid; re-signing ad-hoc."
  codesign --force --deep --sign - "$bundle"
  codesign --verify --deep --strict "$bundle"
fi
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
