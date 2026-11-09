#!/usr/bin/env bash
# Launch the app shipped in a DMG and check that it starts and stays up.
#
#   tool/smoke_test_macos_dmg.sh <Neiroha.dmg> <arm64|x86_64> [seconds]
#
# Run on a Mac of the given architecture (CI uses native runners). Checks:
#   * the main executable is built for exactly that architecture;
#   * the app keeps running for the given time (default 20 s);
#   * it creates its data folder in Application Support, not in the bundle.
set -euo pipefail

usage="usage: $0 <Neiroha.dmg> <arm64|x86_64> [seconds]"
dmg="${1:?$usage}"
arch="${2:?$usage}"
wait_s="${3:-20}"
bundle_id="com.neiroha.neiroha"
data_dir="$HOME/Library/Application Support/$bundle_id"

host="$(uname -m)"
if [[ "$host" != "$arch" ]]; then
  echo "error: host is $host, cannot smoke-test a $arch build natively" >&2
  exit 2
fi

work="$(mktemp -d)"
mnt="$work/mnt"
mkdir "$mnt"
pid=""
cleanup() {
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    sleep 2
    kill -9 "$pid" 2>/dev/null || true
  fi
  hdiutil detach "$mnt" -quiet 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT

hdiutil attach "$dmg" -nobrowse -readonly -mountpoint "$mnt" -quiet
ditto "$mnt/Neiroha.app" "$work/Neiroha.app"
hdiutil detach "$mnt" -quiet
app="$work/Neiroha.app"
exe="$app/Contents/MacOS/Neiroha"

archs="$(lipo -archs "$exe")"
echo "Main executable: $archs"
if [[ "$archs" != "$arch" ]]; then
  echo "error: expected $arch only, got: $archs" >&2
  exit 1
fi
codesign --verify --deep --strict "$app"

log="$work/neiroha.log"
"$exe" >"$log" 2>&1 &
pid=$!
echo "Launched Neiroha (pid $pid), waiting ${wait_s}s..."

ok=1
for _ in $(seq "$wait_s"); do
  sleep 1
  if ! kill -0 "$pid" 2>/dev/null; then
    ok=0
    break
  fi
done

if [[ "$ok" == "1" && ! -d "$data_dir" ]]; then
  echo "error: data folder not created: $data_dir" >&2
  ok=0
fi
if [[ -d "$app/Contents/MacOS/neiroha_data" ]]; then
  echo "error: app wrote data inside its bundle" >&2
  ok=0
fi

echo "---- app log (tail) ----"
tail -n 40 "$log" || true
echo "------------------------"

if [[ "$ok" != "1" ]]; then
  if ! kill -0 "$pid" 2>/dev/null; then
    status=0
    wait "$pid" || status=$?
    echo "error: Neiroha exited early (status $status)" >&2
  fi
  exit 1
fi
echo "Smoke test passed: Neiroha ($arch) ran for ${wait_s}s; data in $data_dir"
ls "$data_dir" || true
