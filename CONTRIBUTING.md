# Contributing to Social Studio

This is a public project. Code quality is part of the product: every change should be something we are proud to show. The same rules apply to human and AI contributors.

## How a change gets in

Everything pushed to this repository is public, including branches. Nothing reaches GitHub before it has been reviewed locally.

1. **Work on a local branch.** Never commit to `main`. Install the hooks once (`tool/install-hooks.sh`); the pre-commit hook runs formatting, static analysis and tests for every package affected by the staged changes, including deletions, on a snapshot of the staged content. Never bypass hooks (`--no-verify`).
2. **Self-review the diff** as a reviewer would: remove dead code, debug output and unrelated changes.
3. **Independent local review, before any push.** Someone (or an AI assistant) other than the author reviews the local branch, starting from the diff and the problem statement, not from the author's reasoning. The reviewer runs the checks and reports findings with file, line, failure scenario and severity. Outcomes: *no blocking findings*, *changes required* or *verification incomplete*. Only the first allows pushing. The reviewer records the outcome for the exact commit with `tool/record-review.sh <reviewer> <outcome>`; the record stays in `.git`, is never pushed, and is invalidated by any amend or rebase. An author cannot record a review of its own change. This prevents accidental publication; it cannot prove independence against someone willing to forge it, so the review is also summarized in the pull request.
4. **Clean the history locally.** Fix findings, then leave a small number of meaningful commits (squash fixups, reword messages). History is rewritten only before the first push, never after.
5. **Push and open the pull request.** The pre-push hook refuses pushes to `main` and remote branch deletions, requires a passing review record for the exact commit, and runs the full checks on **every commit** that would become public. The pull request includes the review outcome.
6. **CI must pass** (once packages exist): formatting, analysis, tests, coverage threshold for the core, schema validation, package score and license checks. `main` is protected: pull requests only, linear history, no force pushes.

## Code standards

### Design

- **Spec first.** Language-neutral data (platform profiles, templates, render jobs) lives in `spec/` as versioned JSON Schemas. Renderers implement the spec; they never redefine it.
- **Small, focused units.** One responsibility per class and file. Prefer composition over inheritance. No "utils" dumping grounds.
- **Explicit over clever.** Clear names, early returns, no hidden global state, no magic numbers (named constants or spec data).
- **Immutable by default.** Value types are immutable; state changes are explicit.
- **Fail loudly and early** on invalid input with typed errors; never silently produce a wrong output.
- **No speculative abstractions.** Extract a shared abstraction when a second real use exists.
- **Reuse before creating.** Check `docs/reuse.md` and search the code. Prefer contributing upstream (for example, to Fluvie) over re-implementing.

### Dart and Flutter

- Follow [Effective Dart](https://dart.dev/effective-dart). Format with `dart format`; no exceptions.
- Strict analysis: `strict-casts`, `strict-inference`, `strict-raw-types`, a strict lint set (for example `very_good_analysis`) and `public_member_api_docs`. Zero analyzer infos, warnings or errors.
- No `dynamic`, no unchecked casts, no `!` to silence a nullable contract.
- Every public API has dartdoc comments that explain behavior, units, failure modes and an example where useful.
- Packages target the highest [pub.dev score](https://pub.dev/help/scoring) and include an `example/`.
- Deterministic rendering: no wall-clock time, randomness or network inside rendering; inject them.

### Tests

- The hooks are code too: `tool/test_hooks.sh` proves every gate rejects what it claims to reject. Run it after changing anything in `tool/`.

- Every behavior has a test; every bug fix starts with a failing test.
- **Every check must be able to fail.** When adding a guard or test, show it fails without the protected behavior (mutation check). A test that cannot fail is removed.
- Visual output is protected by goldens and conformance jobs. Golden updates need explicit review of each changed image; never regenerate goldens to make CI green.
- Synthetic data only. Never real people's photos, voices or transcripts.

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
