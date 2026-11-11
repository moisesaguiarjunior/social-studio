#!/usr/bin/env bash
# The CI/local entry point. It checks this checkout, not an arbitrary package
# inferred from the caller's current directory. Git hooks use snapshots.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
source "$root/tool/hooks/lib.sh"

check_hook_suite "$root" || exit 1
status=0
while IFS= read -r pkg; do
  [ -n "$pkg" ] || continue
  echo "repository checks: ${pkg#"$root"/}"
  check_package "$pkg" || status=1
done < <(packages_in "$root")
exit "$status"
