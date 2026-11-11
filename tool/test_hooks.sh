#!/usr/bin/env bash
# Regression suite for the git hooks: every gate must reject what it claims
# to reject. Runs in a disposable repository with a local bare remote; never
# touches the real remote. Requires the Dart SDK.
set -uo pipefail

src="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
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

cd "$work"
hook_shell="${HOOK_SHELL:-bash}"
git init -q --bare origin.git
git init -q --bare backup.git
git init -q repo
cd repo
git config user.name tester
git config user.email tester@example.com
git remote add origin ../origin.git
git remote add backup ../backup.git
mkdir -p tool pkg/lib
cp -R "$src/." tool/
printf 'name: probe\nenvironment:\n  sdk: ^3.13.0\n' >pkg/pubspec.yaml
printf "import 'helper.dart';\n\nint run() => helper();\n" >pkg/lib/main.dart
printf 'int helper() => 1;\n' >pkg/lib/helper.dart
printf '.dart_tool/\n' >.gitignore
(cd pkg && dart pub get >/dev/null)
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

if [ "$failures" -gt 0 ]; then
  echo "$failures hook check(s) failed"
  exit 1
fi
echo "all hook checks passed"
