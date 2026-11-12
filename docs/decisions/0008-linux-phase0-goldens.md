# 0008 — Linux references for the phase 0 visual regression

Status: proposed in the PR #10 follow-up. Recorded 2026-11-12.

## Context

The repository gate runs on Linux. PR #10 compared fresh Linux captures with
phase 0 evidence PNGs produced on macOS. Font rasterization differs, so the
comparison failed despite unchanged scene code. The evidence and its SHA-256
record must remain historical.

## Decision

- Keep `probes/phase0/evidence/` and its hash record unchanged.
- Store separate, synthetic Linux reference PNGs under
  `probes/phase0/test/goldens/` for frames 0 and 59.
- Run the exact-pixel golden comparison on the pinned Ubuntu 24.04 / Flutter
  3.47.9 CI path. On other development platforms, announce the skip and run
  the repeatability and structural checks.
- Review changed references image by image. A different platform is not a
  reason to introduce pixel tolerance. Mobile and browser visuals need their
  own captures and approval.

## Alternatives and consequences

Reusing macOS evidence makes the required Linux gate fail for platform
rendering differences. A tolerance could hide a small real regression in the
text. A second macOS golden set would not protect the Linux CI path. The
separate Linux set adds two files and one extra capture to the Linux suite,
while leaving the original evaluation reproducible and the nonvisual checks
available on every development platform.
