# Contributing to Social Studio

This is a public project. Code quality is part of the product: every change should be something we are proud to show. The same rules apply to human and AI contributors.

## How a change gets in

Everything pushed to this repository is public, including branches. Nothing reaches GitHub before it has been reviewed locally.

1. **Work on a local branch.** Never commit to `main`. Install the hooks once (`tool/install-hooks.sh`); the pre-commit hook runs formatting, static analysis and tests for every package affected by the staged changes, including deletions, on a snapshot of the staged content. Changes in `tool/` or `.github/workflows/` also run the hook regression suite against that snapshot, even outside a package. Never bypass hooks (`--no-verify`).
2. **Self-review the diff** as a reviewer would: remove dead code, debug output and unrelated changes.
3. **Independent local review, before any push.** Someone (or an AI assistant) other than the author reviews the local branch, starting from the diff and the problem statement, not from the author's reasoning. The reviewer runs the checks and reports findings with file, line, failure scenario and severity. Outcomes: *no blocking findings*, *changes required* or *verification incomplete*. Only the first allows pushing. The reviewer records the outcome for the exact commit with `tool/record-review.sh <reviewer> <outcome>`; the record stays in `.git`, is never pushed, and is invalidated by any amend or rebase. An author cannot record a review of its own change. This prevents accidental publication; it cannot prove independence against someone willing to forge it, so the review is also summarized in the pull request.
4. **Clean the history locally.** Fix findings, then leave a small number of meaningful commits (squash fixups, reword messages). History is rewritten only before the first push, never after.
5. **Push and open the pull request.** The pre-push hook refuses pushes to `main` and remote branch deletions, requires a passing review record for the exact commit, and runs package checks on **every commit** that would become public and hook regressions for tool/workflow changes in each snapshot (including deletions and root commits). The pull request includes the review outcome.
6. **CI must pass for the current head.** The `Repository checks` job runs `bash tool/check.sh`: hook regressions, package formatting, strict analysis and tests. Coverage thresholds, schema/conformance validation and publication checks are added with the core they protect; they are not claimed as implemented by this workflow. Branch protection and a successful workflow are separate settings/evidence. `main` remains pull requests only, with linear history and no force pushes.

## Review the system, not only the diff

Before reading the author's rationale, review the original request, relevant
contracts and actual callers. Record the canonical implementation and consumers
checked. Ask:

- Does this behavior already exist under another name or shape?
- Does this add a second source of truth for state, policy, calculation or configuration?
- Does it fit the real callers and project conventions, including undocumented ones?
- Could the code, tests and documentation share the same wrong premise? Agreement between them is not independent evidence.
- Which important acceptance criterion could be missing while the current tests stay green?

The reviewer may recommend reuse, simplification, redesign or dropping an
unnecessary change even when all checks pass. Existing code can also be wrong:
compare it with requirements and evidence rather than preserving it blindly.
Formatting belongs to automation; naming, cohesion, clarity and safe boundaries
still require engineering judgment. Keep this review proportional to the change.
When a PR changes a gate and its suite together, inspect removed or weakened
assertions and challenge the gate independently; passing its own modified suite
is insufficient.

## Code standards

The rationale and limits of these standards are recorded in
[decision 0004](docs/decisions/0004-review-and-test-policy.md).

### Design

- **Spec first.** Language-neutral data (platform profiles, templates, render jobs) lives in `spec/` as versioned JSON Schemas. Renderers implement the spec; they never redefine it.
- **Small, focused units.** Group code that changes for the same reason, with clear contracts and owners. Avoid unrelated responsibilities and artificial file splits that obscure a simple flow. Prefer composition over inheritance. No "utils" dumping grounds.
- **Explicit over clever.** Clear names, early returns, no hidden global state, no magic numbers (named constants or spec data).
- **Immutable by default.** Value types are immutable; state changes are explicit.
- **Fail loudly and early** on invalid input with typed errors; never silently produce a wrong output.
- **No speculative abstractions.** Extract a shared abstraction when a second real use exists.
- **Reuse before creating.** Check `docs/reuse.md` and search the code. Prefer contributing upstream (for example, to Fluvie) over re-implementing.

### Dart and Flutter

- Follow [Effective Dart](https://dart.dev/effective-dart). Format with `dart format`; no exceptions.
- Strict analysis: `strict-casts`, `strict-inference`, `strict-raw-types`, a strict lint set (for example `very_good_analysis`) and `public_member_api_docs`. Zero analyzer infos, warnings or errors.
- Keep application logic statically typed. No unchecked casts and no `!` to hide a nullable contract. Unavoidable SDK interop may use `dynamic` only inside a narrow boundary that immediately validates/narrows the value and exposes a typed contract; document the necessity and failure behavior for independent review. No global lint suppression or propagating dynamic values through the application.
- Every public API has dartdoc comments that explain behavior, units, failure modes and an example where useful.
- Packages target the highest [pub.dev score](https://pub.dev/help/scoring) and include an `example/`.
- Deterministic rendering: no wall-clock time, randomness or network inside rendering; inject them.

### Tests

- The hooks are code too: `tool/test_hooks.sh` proves every gate rejects what it claims to reject. Run it after changing anything in `tool/`.

- Protect material behavior and failure modes with meaningful regression tests; a bug fix starts with a test that fails for that defect. Do not add getter, generated-code or documentation-mirroring tests just to raise counts.
- **Every check must be able to fail.** Show a relevant invalid case is rejected and the valid case passes. A compiler error, missing tool or another guard is not evidence for the intended protection. A one-off mutation/measurement may run in a disposable copy with commit-bound evidence; it does not require a permanent mutation framework. Keep useful regression tests, especially for recurring safety gates.
- Visual output is protected by goldens and conformance jobs. Golden updates need explicit review of each changed image; never regenerate goldens to make CI green.
- Synthetic data only. Never real people's photos, voices or transcripts.
- **Never commit details of the maintainer's machine or devices**: model, chip, serial number, OS version or build, disk space, computer name, paths containing the user name, device or emulator IDs. This applies to code, docs, evidence, test output, commit messages and pull request descriptions. Describe environments generically ("local development machine", "desktop, not a phone") and record only software versions that matter to a result (Flutter, Dart, packages). Device classes required by criteria (for example "mid-range Android") are fine; the maintainer's specific devices are not. Strip absolute paths and machine identifiers from tool output before committing.

### Dependencies

- Every dependency is justified and recorded in `docs/dependencies.md` with its license. No GPL/AGPL in distributed packages.
- Pin versions with lockfiles; update dependencies in small, separate changes.

## Commits, versions and docs

- [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`), in English, imperative mood, explaining *why* in the body.
- [Semantic Versioning](https://semver.org/) per package, with a `CHANGELOG.md`.
- Durable technical decisions are recorded in `docs/decisions/` (context, decision, alternatives, consequences, evidence).
- Update `docs/reuse.md` and the README in the same change that makes them outdated.

## Pull request checklist

The pull request template repeats this list:

- [ ] Linked issue or clear problem statement
- [ ] Reuse checked (what was searched, what was reused)
- [ ] Hooks ran locally; format, analysis and tests pass
- [ ] New behavior covered by tests that fail without it
- [ ] Goldens or conformance output reviewed image by image, if changed
- [ ] Public API documented; README, reuse map and decisions updated
- [ ] Dependencies and licenses recorded, if changed
- [ ] Independent local review done before the first push; outcome attached
