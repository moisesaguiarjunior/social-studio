# Desktop Story workflow verification

Local, uncommitted implementation evidence for `flutter/social_studio`.
Software: Flutter 3.47.9, Dart 3.13.7, Python 3.10.20, FFmpeg 8.1.2.

## Usable path

From the repository root, generate the existing phase 1 synthetic assets, then
run the package's documented `validate` and `render` commands. The JSON job
produced `story.mp4`, `cover.png` and `result.json`. `ffprobe` reported H.264,
1080 by 1920, 30 fps, AAC and 12.000 seconds. The cover was visually inspected:
the synthetic photo fills the canvas and the first supplied caption is legible.
The media remain gitignored; no reference image was regenerated.

A second render used a one-second WAVE input tagged with the synthetic strings
`Synthetic Device` and `Synthetic Location`. Both output streams measured
12.000 seconds, and neither string appeared in stream/container metadata.
This tests padding and the inspected metadata path, not every possible media
format or a general-purpose metadata sanitizer.

## Failure controls

The regular package tests accept a valid local job and reject unsupported
versions/templates/fields, invalid durations/covers, missing/remote inputs,
empty/overlapping/out-of-range captions, subtitle control text, partial-frame
duration, playlists and nonimage files. Each test begins with a valid fixture;
the image/audio negative controls restore the unrelated input before rejection.

A separate encoder-failure control used an executable that passed the version
probe and then exited 17. The CLI returned failure, left no final directory,
and removed its staging/raw-frame directories. An existing output directory
was also rejected. These controls were run in disposable directories.

The capture draft additionally passed controlled application-frame interleaving
and failed-capture unmount/recovery tests. These do not certify native scheduling
or hardware encoding. The first usable desktop path still uses the published
headless renderer, without adopting those patches.

## Remaining limits

No phone, actual share handoff, native encoder, cross-host golden, arbitrary
plugin network sandbox or interrupted-process cleanup is certified. The first
job/template contract is intentionally limited; see the package README and
roadmap. The synthetic output is an execution example, not an official platform
acceptance result.

## Final local checks

On 2026-11-12, `bash tool/check.sh` exited 0: 42 hook scenarios and 41
top-level Flutter tests (18 desktop job tests, six phase 0 tests, seventeen
phase 1 tests). Formatting and strict analysis were clean. `git diff --check`
also passed.

Independent local review reported **no blocking findings** after rerunning
all 18 desktop tests. Review found and verified fixes for staging cleanup when
temporary-directory creation fails and caption intervals that collapse to zero
frames. Caption validation now preserves the pinned renderer's exact floating
point operation order; the boundary regression failed before that correction.
This is working-tree evidence, not an exact-commit publication attestation.

## Photo sequence increment

On 2026-11-12 the sequence example produced a 12-second H.264/AAC MP4 at
1080 by 1920 and 30 fps (360 frames). Decoded samples at frames 0, 119, 120,
239, 240 and 359 matched the expected three synthetic photos, including both
sides of each cut. The cover was visually inspected and its decoded RGB bytes
matched video frame 150 in the second scene. Both encoded streams measured
12 seconds. The unchanged single-photo example was rendered again; its MP4
and cover were byte-identical to the earlier single-photo output.

Commands executed from the desktop package:

- `python3 tool/generate_sequence_assets.py`
- `dart run bin/social_studio.dart render example/sequence.json out/sequence-v1`
- `dart run bin/social_studio.dart render example/story.json out/single-photo-regression`
- `flutter test --no-pub test/story_job_test.dart test/story_sequence_test.dart`
- `flutter analyze --no-pub`

The real-renderer regression uses a small synthetic canvas to check exact cuts,
caption ink across a scene boundary, absence outside the cue and photo motion.
Disposable mutation controls repeated the first image, removed captions,
disabled the duration-sum check, disabled whole-frame scene validation and
removed the scene-count limit. Each was rejected by the intended assertion.
The oversized input still sums to the valid total, so duration validation
cannot mask a missing scene-count limit. Temporary copies were removed.
The sequence acceptance test also failed against the original single-photo
schema before implementation.

`bash tool/check.sh` passed again from the repository root: 42 hook scenarios
and 47 top-level Flutter tests (24 desktop, six phase 0, seventeen phase 1).
Formatting, strict analysis and `git diff --check` passed. An independent local
review reran all 24 desktop tests and analysis, inspected the canonical scene,
caption, mux and cover callers, and reported **no blocking findings**. Software
versions are unchanged from the opening record. No phone validation or upstream
patch adoption is implied.

## Portable review increment

The desktop `render` command now also writes `review.html` and `captions.srt`
inside staging before exposing the completed directory. The sequence example
was rendered to `out/review-v1`; its MP4 and cover are byte-identical to the
previous sequence export. The actual `result.json` passed the canonical result
schema, all referenced local artifacts existed, and the exported SRT matched
`StoryJob.toSrt()` exactly.

`bash tool/check.sh` passed: 42 hook scenarios and 51 top-level Flutter tests
(28 desktop, six phase 0, seventeen phase 1), with clean formatting and strict
analysis. `git diff --check` passed. Disposable mutation controls confirmed that
removing HTML escaping and changing caption rounding to floor fail the intended
assertions. Temporary verification code and checkout copies were removed.

An isolated JavaScript simulation executed the generated page script with
minimal DOM/media stand-ins. It checked queued seeking before metadata, scene
selection, a caption spanning a cut, caption selection, playback-end state and
media-error display. Node 26.5.0 was used only for this manual verification;
it is not a package or test-suite dependency. Other software versions are
unchanged from the opening record.

Independent review found no blocking issue in the code or executed checks and
confirmed canonical Fluvie timing semantics, escaped text, fixed output links
and existing staging cleanup. Its overall outcome is **verification incomplete**
for actual browser playback/layout. Opening the local file through browser
automation was explicitly rejected by the browser URL policy; no workaround was
attempted. Actual browser decoding, keyboard behavior, local-file compatibility
and responsive visual layout remain unverified. The isolated simulation is not
browser evidence, and the page is not a mobile/share certification.

## Frozen job correction

The CLI no longer passes the source JSON to the capture subprocess. The first
validated job writes a private snapshot containing a normalized job, profile,
template and schema text retained from that load. Media references are rebased
against the real temporary-directory path (including symbolic-link aliases).
Capture reads only that snapshot. Review, SRT, mux configuration and cover
selection retain the same loaded job. Snapshot files are removed by existing
workspace cleanup. Media bytes are referenced, not copied or frozen.

`test/frozen_job_test.dart` runs the actual CLI in a disposable checkout with a
small synthetic canvas. An encoder wrapper changes the original JSON during
the version probe, after initial validation and before capture. The replacement
adds a blue second scene and changes the caption. The successful run checks
that the source really changed, review and SRT retain the original caption,
and the decoded MP4 still shows the original red photo at six seconds.

A temporary mutation of the disposable CLI restored the original job path for
capture. The same regression failed at the decoded-video assertion, reproducing
the mismatch rather than merely a tool or compilation failure. Temporary copies
were removed. Independent review reran the new regression and job validation
(24 tests), analysis and diff checks, reporting **no blocking findings for this
correction**. Browser and phone verification remain pending.

After this correction, `bash tool/check.sh` passed: 42 hook scenarios and 52
Flutter tests (29 desktop, six phase 0, seventeen phase 1), with clean formatting
and strict analysis. `git diff --check` also passed. Software versions remain
Flutter 3.47.9, Dart 3.13.7, Python 3.10.20 and FFmpeg 8.1.2.


## Refresh onto main and media integrity

The local work was reapplied onto main `377153ad53558569a88a517bcf82ca3d1af4f33d`.
The accepted v0 schemas, catalog, checker, hooks and decisions remain unchanged.
The desktop contract remains explicitly scoped separately; v0 catalog rendering
is not claimed by this package.

Validated jobs retain SHA-256 digests for each distinct image/audio file. Hashing
uses bounded chunks and the already inventoried `crypto` package. Checks before
capture and before the final directory rename reject persistent replacements,
removed files and unreadable files. This is detection, not a filesystem snapshot:
a temporary replacement restored between checks can evade it.

The CLI regression now includes a valid image replacement during cover extraction,
after capture and encoding. The final check rejects the export and staging is
removed. A disposable mutation removed only the final check while retaining the
pre-capture check; the export incorrectly succeeded and the regression failed
at its exit-code assertion. The disposable test file and render workspace were
removed. Unit controls additionally reject modified images, modified audio and
removed files, with unchanged/restored media as valid controls.

On the refreshed base, `bash tool/check.sh` passed: 51 hook scenarios, 57 v0
schema tests and 54 Flutter tests (31 desktop, six phase 0, seventeen phase 1).
Formatting and strict analysis were clean. Staged diff whitespace checks and a
scan for personal paths, device markers and coordination prompts passed.
Independent local review reported no blocking findings for the main refresh and
media-integrity change. This is pre-commit evidence; an exact-commit review is
still required before push. Software versions remain Flutter 3.47.9, Dart
3.13.7, Python 3.10.20 and FFmpeg 8.1.2. Browser and phone verification remain
pending.

## Desktop authoring namespace and catalog consistency

The renderer-specific authoring documents now live in `spec/desktop-story`.
They are not catalog schema v1. ADR0005 records the catalog-to-renderer adapter,
shared-fixture verification and migration sequence; ADR0003 remains authoritative
for future numbered catalog schema versions.

The schema suite invoked by `tool/check.sh` and staged spec hooks now compares
the actual desktop profile with the canonical Instagram Story share maximum.
The comparison reuses v0's duration scale and rejects drift on either side,
missing/reclassified canonical rules, wrong units and invalid projected values.
A disposable copy changed only the desktop limit: the actual schema suite
failed at the checked-in consistency assertion. Independent review also disabled
the comparison and confirmed that the negative tests fail. No platform requirement
or schema v0 version was changed.

The old Fluvie lifecycle draft is now prominently marked as superseded by the
later correction set. Its checker remains a historical reproduction and does
not validate the replacement or adopt it. The PR scope description is kept in
private Git metadata rather than public coordination documents.
