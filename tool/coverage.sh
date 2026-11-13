#!/usr/bin/env bash
# Measure the desktop library with its existing tests, not the historical probes.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
package="$root/flutter/social_studio"
mkdir -p "$root/coverage"
# Never upload a report from a previous successful run after a failed run.
rm -f "$root/coverage/lcov.info" "$package/coverage/lcov.info"
(
  source "$root/tool/hooks/lib.sh"
  clear_git_environment
  cd "$package"
  flutter pub get --offline --enforce-lockfile || flutter pub get --enforce-lockfile
  flutter test --coverage
)
report="$package/coverage/lcov.info"
if [ ! -s "$report" ] || ! grep -q '^DA:[0-9][0-9]*,[0-9][0-9]*' "$report"; then
  echo 'coverage: missing or empty line coverage report.' >&2
  exit 1
fi
if ! grep -q '^SF:lib/' "$report" || grep '^SF:' "$report" | grep -qv '^SF:lib/'; then
  echo 'coverage: expected package-relative library source paths.' >&2
  exit 1
fi
sed 's|^SF:|SF:flutter/social_studio/|' "$report" > "$root/coverage/lcov.info"
echo 'coverage: wrote coverage/lcov.info (desktop library only; no percentage gate).'
