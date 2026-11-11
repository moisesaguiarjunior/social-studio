# Repository gate verification

The hook implementation was already covered by `tool/test_hooks.sh`, but only
manual execution invoked it. A tool-only change belonged to no Dart package,
so the hooks could accept it without running the regression suite.

## Reuse and behavior

`check_package` remains the single package checker and enforces the committed
lockfile for both offline and online dependency resolution. `check_hook_suite` runs the
existing regression driver with Git's exported context cleared.
`hook_checks_required` classifies tool/workflow paths, including deleted files. Changed paths use NUL delimiters throughout classification
and staged package lookup, preserving Unicode, quotes and embedded newlines.
Pre-commit uses an index snapshot; pre-push uses every newly published commit's
archive and changed paths. A missing regression suite fails closed.

`tool/check.sh` checks the current checkout, independent of installed hooks. CI
calls it with read-only repository permissions, full-revision action pins and
no event path filters. This is distinct from enforcing branch-protection checks;
do not claim protection or a passing remote run before verifying those states.

## Avoiding recursive tests

The regression driver creates isolated repositories and bare local remotes.
Their `tool/test_hooks.sh` is an intentionally tiny pass/fail fixture, not the
real regression driver. This exercises whether a snapshot invokes its suite
without recursively starting all scenarios when a root/tool commit is checked.
Fixture commits deliberately construct invalid histories inside disposable
repositories; no test bypasses the hooks of this working repository or pushes
to the actual GitHub remote.

## Regression evidence

Seven new negative cases first failed against the old hooks because invalid
changes were accepted: staged failing suite, deleted suite, tool-only change,
workflow change, committed failing suite, bad intermediate suite, and committed
suite deletion. Positive controls accept a valid suite and unrelated docs.
The CI entry point also rejects a broken package, a missing lockfile and a
failing regression suite. The driver fails closed if sandbox setup fails and
clears inherited Git context before creating fixture repositories.

The prior cases for index contents, deletions, exact-head reviews, split remotes,
empty destinations and linked worktrees are retained.

Mutation controls keep the scripts syntactically valid (a no-op replaces an
invocation where needed); a syntax error is not counted as detecting the gate.

Local self-verification: 37 hook scenarios pass, including the prior controls;
all six existing phase 0 Flutter tests pass; format and strict analysis are
clean. Four valid-syntax mutations were detected: removing pre-commit,
pre-push, CI hook-suite invocation, or lockfile enforcement. Workflow YAML
parses and shell syntax checks pass. Generated phase 0 frame hashes remain
unchanged; no golden was regenerated.

Independent review of the first candidate found that Git-quoted filenames
escaped the classifier. Six additional regressions (Unicode, quotes and newlines
in both hooks) reject that implementation and pass with NUL-delimited paths.
Independent reconfirmation of the corrected commit is required before push. Remote CI
results and branch-protection settings are recorded separately after the pull
request exists; local verification does not claim a GitHub run.
No golden reference, phone performance or phase 1 rendering result is changed
or certified by these repository checks.
