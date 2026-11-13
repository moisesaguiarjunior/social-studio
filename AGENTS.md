# Working in this repository

Everything here is in English: code, docs, commits. Read [README.md](README.md) for goals, non-goals and phases, and [CONTRIBUTING.md](CONTRIBUTING.md) for the code standards, which are binding.

This is a public repository: the bar is state-of-the-art, clean code. Everything pushed is public, including branches: **never push before an independent local review**. `main` is protected; changes enter through pull requests. Run `tool/install-hooks.sh` once; never bypass the hooks.

Use [docs/README.md](docs/README.md) to find canonical contracts, implementation
entry points and verification records by task.

## Before writing code

1. Check `docs/reuse.md` and search the repository for an existing solution. Note what you searched.
2. Plan with **Reuse** and **Create**. Prefer contributing to an upstream dependency (for example, Fluvie) over re-implementing what it already does.
3. Read `docs/decisions/` for accepted technical decisions. Record new durable decisions there (context, decision, alternatives, consequences, evidence).

## Rules

- Language-neutral data (platform profiles, templates, render jobs) lives in `spec/` as versioned JSON Schemas. Renderers implement the spec; they do not redefine it.
- Every platform number (size, duration, file limit, safe zone) cites an official source and the date it was checked.
- No network access during rendering. No analytics on content. Strip location and device metadata from outputs.
- Synthetic data only in fixtures, examples, goldens and conformance jobs. Never real people's photos, voices or transcripts.
- **Never commit details of the maintainer's machine or devices**: model, chip, serial number, OS version or build, disk space, computer name, paths containing the user name, device or emulator IDs. This applies to code, docs, evidence, test output, commit messages and pull request descriptions. Describe environments generically ("local development machine", "desktop, not a phone") and record only software versions that matter to a result (Flutter, Dart, packages). Device classes required by criteria (for example "mid-range Android") are fine; the maintainer's specific devices are not. Strip absolute paths and machine identifiers from tool output before committing.
- No GPL/AGPL dependencies in distributed packages. Record every dependency license in `docs/dependencies.md`.
- No bundled copyrighted music.
- The engine never decides what may be shared; consuming apps pass only authorized content.
- Every check must be able to fail: when adding a test or guard, show that it fails without the protected behavior. Do not regenerate goldens to make tests pass.

## Before finishing

Run `bash tool/check.sh` (hook regressions plus package format, strict analysis and tests). Report commands, results, relevant software versions and unverified behavior. Never include identifying machine/device details; see CONTRIBUTING.md.

## Reviews

Changes are reviewed by another assistant (Codex or Claude), starting without the author's reasoning. Review against the existing system and original requirement, not only the diff: search canonical implementations/callers, second sources of truth and missing acceptance criteria. Code, tests and docs may share a wrong premise. Run the checks and report findings with file, line, failure scenario and severity. Outcomes: no blocking findings, changes required, or verification incomplete.
