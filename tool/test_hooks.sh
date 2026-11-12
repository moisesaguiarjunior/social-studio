#!/usr/bin/env bash
# Regression suite for the git hooks: every gate must reject what it claims
# to reject. Runs in a disposable repository with a local bare remote; never
# touches the real remote. Requires the Dart SDK.
set -uo pipefail

src="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)" || exit 1
trap 'rm -rf "$work"' EXIT
zero=0000000000000000000000000000000000000000
failures=0

expect() { # expect <reject|pass> <description> <exit code>
  if { [ "$1" = reject ] && [ "$3" -ne 0 ]; } || { [ "$1" = pass ] && [ "$3" -eq 0 ]; }; then
    echo "ok   $2"
  else
    echo "FAIL $2 (expected $1, exit $3)"
    failures=$((failures + 1))
  fi
}
# push <stdin line> [remote] [push url]: runs pre-push as git does, with the
# remote name and the URL actually pushed to.
push() { echo "$1" | "$hook_shell" tool/hooks/pre-push "${2:-origin}" "${3:-../${2:-origin}.git}" >/dev/null 2>&1; }
raw_commit() { git -c core.hooksPath=/dev/null commit -q "$@"; }

source "$src/hooks/lib.sh" || exit 1
clear_git_environment || exit 1
cd "$work" || exit 1
hook_shell="${HOOK_SHELL:-bash}"
git init -q --bare origin.git || exit 1
git init -q --bare backup.git || exit 1
git init -q repo || exit 1
cd repo || exit 1
git config user.name tester
git config user.email tester@example.com
git remote add origin ../origin.git
git remote add backup ../backup.git
mkdir -p tool pkg/lib || exit 1
cp -R "$src/." tool/ || exit 1
# Fixture commits contain a tiny suite, not this driver: checking a root
# commit or a tool change must not recursively start the full driver.
printf '#!/usr/bin/env bash\nexit 0\n' >tool/test_hooks.sh
printf 'name: probe\nenvironment:\n  sdk: ^3.13.0\n' >pkg/pubspec.yaml
printf "import 'helper.dart';\n\nint run() => helper();\n" >pkg/lib/main.dart
printf 'int helper() => 1;\n' >pkg/lib/helper.dart
printf '.dart_tool/\n' >.gitignore
(cd pkg && dart pub get >/dev/null) || exit 1
git add -A
raw_commit -m init
git -c core.hooksPath=/dev/null push -q origin HEAD:main
git checkout -q -b feature

printf 'int run( => ;\n' >pkg/lib/main.dart
git add pkg/lib/main.dart
printf "import 'helper.dart';\n\nint run() => helper();\n" >pkg/lib/main.dart
bash tool/hooks/pre-commit >/dev/null 2>&1
expect reject "pre-commit checks the staged content, not the working tree" $?
git reset -q --hard

git rm -q pkg/lib/helper.dart
bash tool/hooks/pre-commit >/dev/null 2>&1
expect reject "pre-commit runs on deletions" $?
git reset -q --hard

printf 'int helper() => 2;\n' >pkg/lib/helper.dart
git add -A
bash tool/hooks/pre-commit >/dev/null 2>&1
expect pass "pre-commit accepts a clean change" $?
raw_commit -m "feat: change helper" -m "Co-Authored-By: Claude <noreply@anthropic.com>"
tip="$(git rev-parse HEAD)"
base="$(git rev-parse origin/main)"

push "refs/heads/feature $tip refs/heads/feature $zero"
expect reject "pre-push requires a review attestation" $?

bash tool/record-review.sh "Claude" no-blocking-findings >/dev/null 2>&1
expect reject "an author cannot attest its own change" $?

bash tool/record-review.sh Reviewer changes-required >/dev/null 2>&1
push "refs/heads/feature $tip refs/heads/feature $zero"
expect reject "pre-push rejects a review that required changes" $?

bash tool/record-review.sh Reviewer no-blocking-findings >/dev/null 2>&1
push "refs/heads/feature $tip refs/heads/feature $zero"
expect pass "pre-push accepts a reviewed, clean commit" $?

push "refs/heads/main $tip refs/heads/main $base"
expect reject "pre-push refuses main" $?

printf 'int helper( => ;\n' >pkg/lib/helper.dart
git add -A
raw_commit -m "wip"
printf 'int helper() => 3;\n' >pkg/lib/helper.dart
git add -A
raw_commit -m "fix"
bash tool/record-review.sh Reviewer no-blocking-findings >/dev/null 2>&1
push "refs/heads/feature $(git rev-parse HEAD) refs/heads/feature $zero"
expect reject "pre-push checks every commit that would become public" $?

git reset -q --hard "$tip"
raw_commit --amend -m "feat: reworded"
push "refs/heads/feature $(git rev-parse HEAD) refs/heads/feature $zero"
expect reject "a review is bound to the exact commit" $?

push "(delete) $zero refs/heads/feature $tip"
expect reject "pre-push refuses remote branch deletion" $?

# A commit already on another remote (for example a private backup) is not
# on the destination yet: it must still be checked before going public.
git checkout -q -b from-backup "$base"
printf 'int helper( => ;\n' >pkg/lib/helper.dart
git add -A
raw_commit -m "broken, pushed only to backup"
git -c core.hooksPath=/dev/null push -q backup HEAD:refs/heads/from-backup
bash tool/record-review.sh Reviewer no-blocking-findings >/dev/null 2>&1
push "refs/heads/from-backup $(git rev-parse HEAD) refs/heads/from-backup $zero" origin
expect reject "pre-push checks commits known only to another remote" $?

# A remote that fetches from a private URL and pushes to the public one: its
# remote-tracking refs describe the private side, not the destination.
git remote add mixed ../backup.git
git remote set-url --push mixed ../origin.git
git -c core.hooksPath=/dev/null fetch -q mixed
push "refs/heads/from-backup $(git rev-parse HEAD) refs/heads/from-backup $zero" mixed ../origin.git
expect reject "pre-push asks the push destination, not the fetch side" $?

push "refs/heads/feature $tip refs/heads/feature $zero" origin ../missing.git
expect reject "pre-push fails closed when the destination cannot be queried" $?

git init -q --bare ../empty.git
push "refs/heads/feature $tip refs/heads/feature $zero" origin ../empty.git
expect pass "pre-push accepts a reviewed commit to an empty destination" $?

# Git exports GIT_DIR and friends to hooks, always in linked worktrees.
# Flutter derives its own version through git, so those variables must not
# reach the package checks. A stub `flutter` fails if they leak.
mkdir -p "$work/stub"
cat >"$work/stub/flutter" <<'STUB'
#!/usr/bin/env bash
if [ -n "${GIT_DIR:-}${GIT_INDEX_FILE:-}${GIT_WORK_TREE:-}" ]; then
  echo "git variables leaked into flutter" >&2
  exit 1
fi
exit 0
STUB
chmod +x "$work/stub/flutter"
git checkout -q main
git worktree add -q ../linked
(
  cd ../linked
  git config core.hooksPath tool/hooks
  mkdir -p app/lib
  printf 'name: app\nenvironment:\n  sdk: ^3.13.0\ndependencies:\n  flutter:\n    sdk: flutter\n' >app/pubspec.yaml
  printf 'int answer() => 42;\n' >app/lib/app.dart
  git add app
  PATH="$work/stub:$PATH" git commit -q -m "feat: flutter package from a linked worktree" >/dev/null 2>&1
)
expect pass "hooks clear git variables before running flutter (linked worktree)" $?

# A review recorded in one linked worktree must be visible to a push made
# from another worktree of the same repository.
git checkout -q feature
git worktree add -q --detach ../reviewer feature
(cd ../reviewer && bash tool/record-review.sh Reviewer no-blocking-findings >/dev/null 2>&1)
push "refs/heads/feature $(git rev-parse feature) refs/heads/feature $zero"
expect pass "a review recorded in another worktree is honored on push" $?

# Changes outside a package still need the hook regression gate. Every
# command below targets only this disposable repository and its bare remote.
git reset -q --hard "$tip"
printf '#!/usr/bin/env bash\nexit 7\n' >tool/test_hooks.sh
git add tool/test_hooks.sh
printf '#!/usr/bin/env bash\nexit 0\n' >tool/test_hooks.sh
bash tool/hooks/pre-commit >/dev/null 2>&1
expect reject "hook regressions use the staged suite, not a fixed working copy" $?
git reset -q --hard "$tip"

git rm -q tool/test_hooks.sh
bash tool/hooks/pre-commit >/dev/null 2>&1
expect reject "deleting the hook suite fails closed" $?
git reset -q --hard "$tip"

printf '#!/usr/bin/env bash\nexit 9\n' >tool/test_hooks.sh
git add tool/test_hooks.sh
raw_commit -m "fixture: failing hook suite"
bad_suite="$(git rev-parse HEAD)"
printf 'hook change\n' >tool/note.txt
git add tool/note.txt
bash tool/hooks/pre-commit >/dev/null 2>&1
expect reject "tool changes outside any package run hook regressions" $?
git reset -q --hard "$bad_suite"

# Only the unusual-name commit is new to this fixture destination: an older
# failing-suite commit must not mask a missed path match in pre-push.
git init -q --bare ../path-origin.git
git -c core.hooksPath=/dev/null push -q ../path-origin.git "$bad_suite:refs/heads/base"
for unusual in 'tool/unicode-é.sh' 'tool/quoted"name.sh' $'tool/newline\nname.sh'; do
  printf 'tool change\n' >"$unusual"
  git add -- "$unusual"
  bash tool/hooks/pre-commit >/dev/null 2>&1
  expect reject "pre-commit detects unusual path: $unusual" $?
  raw_commit -m "fixture: unusual tool path"
  bash tool/record-review.sh Reviewer no-blocking-findings >/dev/null 2>&1
  push "refs/heads/feature $(git rev-parse HEAD) refs/heads/feature $zero" path-origin
  expect reject "pre-push detects unusual path: $unusual" $?
  git reset -q --hard "$bad_suite"
done

mkdir -p .github/workflows
printf 'name: fixture\n' >.github/workflows/fixture.yml
git add .github/workflows/fixture.yml
bash tool/hooks/pre-commit >/dev/null 2>&1
expect reject "workflow changes run hook regressions" $?
git reset -q --hard "$bad_suite"

printf 'documentation only\n' >note.md
git add note.md
bash tool/hooks/pre-commit >/dev/null 2>&1
expect pass "unrelated documentation does not run hook regressions" $?
git reset -q --hard "$bad_suite"

bash tool/record-review.sh Reviewer no-blocking-findings >/dev/null 2>&1
push "refs/heads/feature $bad_suite refs/heads/feature $zero"
expect reject "pre-push rejects a committed failing suite" $?
printf '#!/usr/bin/env bash\nexit 0\n' >tool/test_hooks.sh
git add tool/test_hooks.sh
raw_commit -m "fixture: repair suite after a bad intermediate commit"
bash tool/record-review.sh Reviewer no-blocking-findings >/dev/null 2>&1
push "refs/heads/feature $(git rev-parse HEAD) refs/heads/feature $zero"
expect reject "pre-push runs the hook suite in each newly published commit" $?
git reset -q --hard "$tip"

git rm -q tool/test_hooks.sh
raw_commit -m "fixture: remove hook suite"
bash tool/record-review.sh Reviewer no-blocking-findings >/dev/null 2>&1
push "refs/heads/feature $(git rev-parse HEAD) refs/heads/feature $zero"
expect reject "pre-push rejects removal of the hook suite" $?
git reset -q --hard "$tip"

printf 'safe tool change\n' >tool/note.txt
git add tool/note.txt
bash tool/hooks/pre-commit >/dev/null 2>&1
expect pass "a passing hook suite accepts a tool-only change" $?
raw_commit -m "fixture: safe tool change"
bash tool/record-review.sh Reviewer no-blocking-findings >/dev/null 2>&1
push "refs/heads/feature $(git rev-parse HEAD) refs/heads/feature $zero"
expect pass "pre-push accepts a reviewed passing hook suite" $?

# CI uses the same checked-in entry point, independent of installed hooks.
bash tool/check.sh >/dev/null 2>&1
expect pass "the CI entry point accepts a clean checkout" $?
printf 'int helper( => ;\n' >pkg/lib/helper.dart
bash tool/check.sh >/dev/null 2>&1
expect reject "the CI entry point rejects a failing package" $?
printf 'int helper() => 2;\n' >pkg/lib/helper.dart
rm pkg/pubspec.lock
bash tool/check.sh >/dev/null 2>&1
expect reject "repository checks require the committed lockfile" $?
# Restore the fixture lock without weakening checks in the real repository.
git restore pkg/pubspec.lock
printf '#!/usr/bin/env bash\nexit 6\n' >tool/test_hooks.sh
bash tool/check.sh >/dev/null 2>&1
expect reject "the CI entry point rejects a failing hook suite" $?

# Checkers are subprocess boundaries: neither a package tool nor a regression
# suite may consume the package/ref lists owned by their callers.
git reset -q --hard "$tip"
mkdir -p aaa zzz "$work/stdin-tools"
for pkg in aaa zzz; do
  printf 'name: stdin_probe\nenvironment:\n  sdk: ^3.13.0\n' >"$pkg/pubspec.yaml"
done
cat >"$work/stdin-tools/dart" <<'STUB'
#!/usr/bin/env bash
cat >/dev/null
if [ "$(basename "$PWD")" = zzz ] && [ "${1:-}" = analyze ]; then
  exit 23
fi
exit 0
STUB
chmod +x "$work/stdin-tools/dart"
git add aaa zzz
PATH="$work/stdin-tools:$PATH" bash tool/hooks/pre-commit >/dev/null 2>&1
expect reject "pre-commit checks later packages even when a tool reads stdin" $?
raw_commit -m "fixture: later package fails analysis"
bash tool/record-review.sh Reviewer no-blocking-findings >/dev/null 2>&1
PATH="$work/stdin-tools:$PATH" push "refs/heads/feature $(git rev-parse HEAD) refs/heads/feature $zero"
expect reject "pre-push checks later packages even when a tool reads stdin" $?
PATH="$work/stdin-tools:$PATH" bash tool/check.sh >/dev/null 2>&1
expect reject "repository checks retain later packages when a tool reads stdin" $?

# A regression-suite subprocess must not swallow another ref from pre-push.
git reset -q --hard "$tip"
printf '#!/usr/bin/env bash\ncat >/dev/null\nexit 0\n' >tool/test_hooks.sh
git add tool/test_hooks.sh
raw_commit -m "fixture: passing suite reads stdin"
bash tool/record-review.sh Reviewer no-blocking-findings >/dev/null 2>&1
ref="refs/heads/feature $(git rev-parse HEAD) refs/heads/feature $zero"
PATH="$work/stdin-tools:$PATH" push "$ref"
expect pass "a passing stdin-reading suite and tool remain valid" $?
PATH="$work/stdin-tools:$PATH" push "$ref
refs/heads/feature $(git rev-parse HEAD) refs/heads/main $base"
expect reject "a suite cannot consume a later prohibited push ref" $?

# Schema gates. The clean CI case above has no spec/schemas, so it does not
# run the schema suite. These cases copy the real spec into this disposable
# repository. They push only to its local bare remotes.
printf '#!/usr/bin/env bash\nexit 0\n' >tool/test_hooks.sh
git checkout -q feature
git reset -q --hard "$tip"
studio="$(cd "$src/.." && pwd)"
copy_spec() {
  rm -rf spec
  python3 - "$studio/spec" spec <<'PY'
import shutil
import sys

shutil.copytree(
    sys.argv[1],
    sys.argv[2],
    ignore=shutil.ignore_patterns("__pycache__", "*.pyc"),
)
PY
}

copy_spec
git add spec
bash tool/hooks/pre-commit >/dev/null 2>&1
expect pass "pre-commit runs schema tests for a staged spec change" $?

printf 'import sys\nraise SystemExit(1)\n' >spec/tool/test_validate_spec.py
git add spec/tool/test_validate_spec.py
cp "$studio/spec/tool/test_validate_spec.py" spec/tool/test_validate_spec.py
bash tool/hooks/pre-commit >/dev/null 2>&1
expect reject "pre-commit checks the staged spec, not the working tree" $?

git reset -q --hard "$tip"
copy_spec
git add spec
# The file is new in this fixture commit, so removal needs --force.
git rm -q -f spec/tool/test_validate_spec.py
bash tool/hooks/pre-commit >/dev/null 2>&1
expect reject "deleting the schema suite fails closed" $?

# The failing suite is already on this fixture destination. Only the unusual
# path is new, so a missed name match would skip the suite and accept the push.
git reset -q --hard "$tip"
copy_spec
printf 'import sys\nraise SystemExit(1)\n' >spec/tool/test_validate_spec.py
git add spec
raw_commit -m "fixture: failing schema suite"
bad_spec="$(git rev-parse HEAD)"
git init -q --bare ../spec-path-origin.git
git -c core.hooksPath=/dev/null push -q ../spec-path-origin.git "$bad_spec:refs/heads/base"
printf 'schema\n' >$'spec/newline\nname.json'
git add -- $'spec/newline\nname.json'
bash tool/hooks/pre-commit >/dev/null 2>&1
expect reject "pre-commit detects an unusual spec path" $?
raw_commit -m "fixture: unusual spec path"
bash tool/record-review.sh Reviewer no-blocking-findings >/dev/null 2>&1
push "refs/heads/feature $(git rev-parse HEAD) refs/heads/feature $zero" spec-path-origin
expect reject "pre-push detects an unusual spec path" $?

git reset -q --hard "$tip"
printf '#!/usr/bin/env bash\nexit 0\n' >tool/test_hooks.sh
copy_spec
bash tool/check.sh >/dev/null 2>&1
expect pass "the CI entry point runs schema tests when schemas are present" $?
rm spec/tool/test_validate_spec.py
bash tool/check.sh >/dev/null 2>&1
expect reject "the CI entry point fails closed when the schema suite is missing" $?

# The schema suite is a subprocess boundary. Reading its stdin must not
# swallow a later ref from pre-push.
git reset -q --hard "$tip"
mkdir -p spec/schemas spec/tool
printf '{}\n' >spec/schemas/marker.json
printf 'import sys\nsys.stdin.read()\n' >spec/tool/test_validate_spec.py
git add spec
raw_commit -m "fixture: schema suite reads stdin"
bash tool/record-review.sh Reviewer no-blocking-findings >/dev/null 2>&1
ref="refs/heads/feature $(git rev-parse HEAD) refs/heads/feature $zero"
push "$ref"
expect pass "a passing schema suite that reads stdin remains valid" $?
push "$ref
refs/heads/feature $(git rev-parse HEAD) refs/heads/main $base"
expect reject "a schema suite cannot consume a later prohibited push ref" $?

# The package gate keeps structural tests on every platform while restricting
# exact visual references to Linux. Fake only the external runner and platform;
# exercise the real check_package branch and inspect its test arguments.
mkdir -p "$work/platform-stub" "$work/platform-pkg/test"
printf 'name: platform_probe\nenvironment:\n  sdk: ^3.13.0\ndependencies:\n  flutter:\n    sdk: flutter\n' >"$work/platform-pkg/pubspec.yaml"
printf 'void main() {}\n' >"$work/platform-pkg/test/probe.dart"
cat >"$work/platform-stub/flutter" <<'STUB'
#!/usr/bin/env bash
if [ "$1" = test ]; then printf '%s\n' "$*" >>"$PLATFORM_TEST_LOG"; fi
exit 0
STUB
cat >"$work/platform-stub/uname" <<'STUB'
#!/usr/bin/env bash
if [ "${1:-}" = -s ]; then printf '%s\n' "$PLATFORM_NAME"; else /usr/bin/uname "$@"; fi
STUB
chmod +x "$work/platform-stub/flutter" "$work/platform-stub/uname"
platform_log="$work/platform-tests.log"
platform_output="$work/platform-output.log"
: >"$platform_log"
PATH="$work/platform-stub:$PATH" PLATFORM_NAME=Darwin PLATFORM_TEST_LOG="$platform_log" \
  check_package "$work/platform-pkg" >"$platform_output" 2>&1
expect pass "non-Linux package checks remain runnable" $?
if grep -qx 'test --exclude-tags golden' "$platform_log" \
  && grep -q 'Linux golden comparisons skipped' "$platform_output"; then
  echo "ok   non-Linux package checks announce and skip exact goldens"
else
  echo "FAIL non-Linux package checks must announce and skip exact goldens"
  failures=$((failures + 1))
fi
: >"$platform_log"
PATH="$work/platform-stub:$PATH" PLATFORM_NAME=Linux PLATFORM_TEST_LOG="$platform_log" \
  check_package "$work/platform-pkg" >"$platform_output" 2>&1
expect pass "Linux package checks remain runnable" $?
if grep -qx test "$platform_log"; then
  echo "ok   Linux package checks run the exact goldens"
else
  echo "FAIL Linux package checks must run the exact goldens"
  failures=$((failures + 1))
fi

if [ "$failures" -gt 0 ]; then
  echo "$failures hook check(s) failed"
  exit 1
fi
echo "all hook checks passed"
