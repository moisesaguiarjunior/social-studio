#!/usr/bin/env bash
# Shared helpers for the git hooks. Checks always run on a snapshot of the
# content that will be committed or pushed, never on the working tree.

# check_package <dir>: format, analysis and tests for one Dart/Flutter package.
# Every step fails explicitly: callers may use `check_package || ...`, where
# `set -e` is ignored by bash, so no step may rely on it.
check_package() {
  local pkg="$1" runner=dart
  if grep -q 'sdk: flutter' "$pkg/pubspec.yaml"; then runner=flutter; fi
  (
    cd "$pkg" || exit 1
    "$runner" pub get --offline >/dev/null 2>&1 || "$runner" pub get >/dev/null || exit 1
    dart format --output=none --set-exit-if-changed . || exit 1
    "$runner" analyze --fatal-infos || exit 1
    if [ -d test ]; then "$runner" test || exit 1; fi
  )
}

# packages_in <root>: every directory under <root> containing a pubspec.yaml.
packages_in() {
  find "$1" -name pubspec.yaml -not -path '*/.dart_tool/*' -not -path '*/build/*' \
    -exec dirname {} \; | sort
}

# package_of <root> <path>: the nearest package directory containing <path>,
# relative to <root>; empty when the path is outside every package.
package_of() {
  local root="$1" dir
  dir="$(dirname "$2")"
  while :; do
    if [ -f "$root/$dir/pubspec.yaml" ]; then
      printf '%s\n' "$dir"
      return
    fi
    [ "$dir" = "." ] && return
    dir="$(dirname "$dir")"
  done
}
