#!/usr/bin/env bash
# Shared helpers for the git hooks. Checks always run on a snapshot of the
# content that will be committed or pushed, never on the working tree.

# check_package <dir>: format, analysis and tests for one Dart/Flutter package.
# Standard input is private: SDK/test tools must not consume a caller's
# package/ref stream. Every step fails explicitly: callers may use
# `check_package || ...`, where `set -e` is ignored by bash, so no step
# may rely on it.
check_package() {
  local pkg="$1" runner=dart
  if grep -q 'sdk: flutter' "$pkg/pubspec.yaml"; then runner=flutter; fi
  (
    # Git exports GIT_DIR and friends to hooks (always in linked worktrees).
    # Flutter derives its own version through git, so they must not leak.
    clear_git_environment
    cd "$pkg" || exit 1
    "$runner" pub get --offline --enforce-lockfile >/dev/null 2>&1 ||
      "$runner" pub get --enforce-lockfile >/dev/null || exit 1
    dart format --output=none --set-exit-if-changed . || exit 1
    "$runner" analyze --fatal-infos || exit 1
    if [ -d test ]; then "$runner" test || exit 1; fi
  ) </dev/null
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

# hook_checks_required: consume NUL-delimited paths on stdin. Git quotes
# unusual names without -z; newline-delimited paths also split valid names.
# Drain the input so a pipeline cannot hide a match through SIGPIPE.
hook_checks_required() {
  local file required=1
  while IFS= read -r -d '' file; do
    case "$file" in
      tool/*|.github/workflows/*) required=0 ;;
    esac
  done
  return "$required"
}

# check_hook_suite <snapshot>: never fall through when the suite is deleted.
# The suite owns no caller input; this also protects the outer pre-push ref loop.
check_hook_suite() {
  local snapshot="$1"
  if [ ! -f "$snapshot/tool/test_hooks.sh" ]; then
    echo "hook checks: the regression suite is missing." >&2
    return 1
  fi
  (
    clear_git_environment
    cd "$snapshot" || exit 1
    bash tool/test_hooks.sh || exit 1
  ) </dev/null
}

# spec_checks_required: consume NUL-delimited paths on stdin.
# Return 0 when any path is under spec/. Drain the input so a pipeline
# cannot hide a match through SIGPIPE. Same delimiter rule as
# hook_checks_required: unusual names stay one path.
spec_checks_required() {
  local file required=1
  while IFS= read -r -d '' file; do
    case "$file" in
      spec/*) required=0 ;;
    esac
  done
  return "$required"
}

# check_spec <snapshot>: run the schema suite when this tree has schemas.
# A tree with no spec/schemas is not a schema delivery. Schemas without
# the suite fail closed; deleting the suite must not skip the check.
# Standard input is private, same as check_package and check_hook_suite:
# the suite must not consume a caller's ref list.
check_spec() {
  local snapshot="$1"
  if [ ! -d "$snapshot/spec/schemas" ]; then
    return 0
  fi
  if [ ! -f "$snapshot/spec/tool/test_validate_spec.py" ]; then
    echo "schema checks: the validation suite is missing." >&2
    return 1
  fi
  (
    clear_git_environment
    cd "$snapshot" || exit 1
    python3 spec/tool/test_validate_spec.py || exit 1
  ) </dev/null
}

# Call only in a child environment; SDK commands must not inherit Git's
# context for the repository being committed or pushed.
clear_git_environment() {
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX GIT_COMMON_DIR
}
