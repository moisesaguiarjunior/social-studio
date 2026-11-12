# Render validation follow-up

Scope: the phase 0 visual references and phase 1 timestamp inspector. No new
renderer, dependency, phone measurement or platform requirement is introduced.

## Timing regression

The inspector previously derived flash time from frame index at a fixed 30 fps.
Real synthetic clips at 15, 24 and 60 fps all reported 200 ms for frame 6,
instead of 400, 250 and 100 ms respectively. The new tests failed on those
values before implementation changed. They pass with encoded `pts_time`.
A fourth clip has a nonzero timestamp origin; `-copyts` preserves that origin
for both audio and video measurements. Parser controls cover irregular PTS,
negative PTS, absent PTS and non-finite PTS. A detected event with no usable
timestamp fails rather than silently substituting a later frame.

`video_frame_ms` now reports the first positive observed spacing, as does
`audio_frame_ms`. This is not a promise of constant frame rate or an uncertainty
bound for the entire file. The old historical measurement records are retained.

## Visual regression

At the original `00d4f56` review, the determinism test compared the complete buffers of two fresh
captures. It additionally used Flutter's `matchesGoldenFile` for frames
0 and 59 against the existing PNGs. No golden or stored frame hash was changed.
The unchanged scene passes both comparisons. A disposable-copy mutation from
`Ag Á` to `WRONG` passed the former repeatability test; the same mutation must
fail the new golden comparison. It failed at both reference frames with
6,163 differing pixels per frame; the unchanged scene passed. This is a headless reference check, not a
headless-versus-device equivalence claim.

## Commands and limits

- `flutter test test/inspect_story_test.dart` in `probes/phase1`.
- `flutter test test/determinism_test.dart --reporter expanded` in `probes/phase0`.
- `bash tool/check.sh` from the repository root.

Software used for local verification: Flutter 3.47.9, Dart 3.13.7,
Python 3.10.20 and FFmpeg 8.1.2. Remote CI uses its own documented Python/FFmpeg
environment and must pass separately. No phone, native encode, actual share
handoff, cross-host golden comparison or privacy enforcement is certified here.
The production capture gaps remain open in the [roadmap](../roadmap.md).

Local result: `bash tool/check.sh` exited 0: 42 hook scenarios, six phase 0
Flutter tests and sixteen phase 1 Flutter tests passed; formatting and strict
analysis were clean. `git diff --check` passed and the committed evidence PNGs
and hash file were unchanged. Changes are local and uncommitted; this record
is not an exact-commit publication attestation.

Independent Codex review: **no blocking findings** on the uncommitted change.
The reviewer ran the inspector suite (13 tests) and independently checked a
real variable-rate clip with a 2.4-second origin and a 300 ms cadence gap:
the flash PTS was correctly reported as 3300 ms. Missing/non-finite audio PTS
were rejected. A separate rectangle-color mutation retained repeatability but
failed both goldens (22,540 and 22,701 differing pixels). The reviewer inspected
canonical dependency callers, confirmed the roadmap limits, checked changed
content for machine identifiers, and removed its disposable files.

## Linux CI correction proposed after PR #10

The first CI run of PR #10 found that the two historical phase 0 PNGs were
rendered on macOS and did not exactly match Linux text rasterization. The
follow-up keeps `probes/phase0/evidence/` intact, moves the executable visual
comparison into a separate `golden`-tagged test, and gives that test dedicated
Linux references under `probes/phase0/test/goldens/`. The full-buffer
repeatability check stays untagged and runs everywhere. The repository gate
announces the visual skip outside Linux; CI uses Ubuntu 24.04 and the pinned
Flutter SDK. No pixel tolerance is introduced. The Linux comparison passed
with the unchanged scene. In a disposable copy, changing `Ag Á` to `WRONG`
made both references fail (5,641 differing pixels each). This proves the new
gate detects a repeatably wrong scene. The GitHub CI result still needs to
be checked against the follow-up commit before merge.
