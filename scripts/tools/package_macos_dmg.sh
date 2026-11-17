#!/usr/bin/env bash
# Package a `flutter build macos` bundle into a drag-to-install DMG for one
# CPU architecture.
#
#   scripts/tools/package_macos_dmg.sh <Release|Profile|Debug> <arm64|x86_64> <output.dmg>
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
sign_identity="${NEIROHA_SIGN_IDENTITY:-}"
notary_profile="${NEIROHA_NOTARY_PROFILE:-}"
entitlements="${NEIROHA_SIGN_ENTITLEMENTS:-macos/Runner/Release.entitlements}"
if [[ -n "$notary_profile" && -z "$sign_identity" ]]; then
  echo "error: notarization requires NEIROHA_SIGN_IDENTITY (Developer ID)" >&2
  exit 2
fi

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

if [[ -n "$sign_identity" ]]; then
  # All thinning is finished. Sign nested code from the inside out, then seal
  # the application. Never replace a formal signature with ad-hoc afterwards.
  [[ -f "$entitlements" ]] || { echo "error: missing entitlements: $entitlements" >&2; exit 2; }
  while IFS= read -r -d '' f; do
    file -b "$f" | grep -q 'Mach-O' || continue
    codesign --force --options runtime --timestamp --sign "$sign_identity" "$f"
  done < <(find "$bundle" -depth -type f -print0)
  while IFS= read -r -d '' nested; do
    codesign --force --options runtime --timestamp --sign "$sign_identity" "$nested"
  done < <(find "$bundle/Contents" -depth -type d \( -name '*.framework' -o -name '*.app' -o -name '*.xpc' \) -print0)
  codesign --force --options runtime --timestamp --sign "$sign_identity" \
    --entitlements "$entitlements" "$bundle"
elif [[ "$thinned" -gt 0 ]] || ! codesign --verify --deep --strict "$bundle" 2>/dev/null; then
  echo "Re-signing bundle ad-hoc."
  codesign --force --deep --sign - \
    --preserve-metadata=identifier,entitlements,flags "$bundle"
fi
codesign --verify --deep --strict "$bundle"
codesign -dv "$bundle" 2>&1 | grep -E '^(Identifier|Format|Signature)=' || true

if [[ -n "$notary_profile" ]]; then
  # Staple the application before embedding it in the read-only image, so a
  # user dragging it to Applications retains an offline notarization ticket.
  ditto -c -k --keepParent "$bundle" "$staging/notarize.zip"
  xcrun notarytool submit "$staging/notarize.zip" --keychain-profile "$notary_profile" --wait
  xcrun stapler staple "$bundle"
  xcrun stapler validate "$bundle"
  rm "$staging/notarize.zip"
fi

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
if [[ -n "$sign_identity" ]]; then
  codesign --force --timestamp --sign "$sign_identity" "$out"
fi
if [[ -n "$notary_profile" ]]; then
  xcrun notarytool submit "$out" --keychain-profile "$notary_profile" --wait
  xcrun stapler staple "$out"
  xcrun stapler validate "$out"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$out"
fi
echo "Created $out ($(du -h "$out" | cut -f1))"
