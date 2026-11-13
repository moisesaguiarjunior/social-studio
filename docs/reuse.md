# Reuse map

One line per need: what to use, where it lives, and one consumer. Update in the same change that adds or removes a reusable solution.

| Need | Use | Where | Example consumer |
| --- | --- | --- | --- |
| Package format, strict analysis and tests; Linux-only exact visual references with an explicit skip elsewhere | `check_package` (isolated stdin) | `tool/hooks/lib.sh` | pre-commit, pre-push, `tool/check.sh` |
| Decide whether changed paths affect the hook/CI gates | `hook_checks_required` | `tool/hooks/lib.sh` | staged pre-commit and every unpublished pre-push commit |
| Run the hook regression gate in an isolated Git environment | `check_hook_suite` (isolated stdin) | `tool/hooks/lib.sh` | hooks and `tool/check.sh` |
| Full checkout checks without depending on installed hooks | `bash tool/check.sh` | `tool/check.sh` | Quality workflow, local verification |
| Container reading for one encoded Story (size, `moov` before `mdat`, and `ffprobe` when it runs) | Call `probes/phase0/tool/inspect_story15.py` as a subprocess. Do not copy it | `probes/phase1/tool/inspect_story.py` | Phase 1 Story spike |
| Synthetic swatch | The writer in `probes/phase0/tool/generate_story15_assets.py`, copied. Not extracted. The phase 0 generator is recorded evidence, and this tone is a different length | `probes/phase1/tool/generate_story_assets.py` | `probes/phase1/lib/story_12.dart` |
| Validate a platform profile, a template, and a render job | `validate_spec.py` | `spec/tool/validate_spec.py` | `spec/tool/test_validate_spec.py`, `check_spec` |
| Decide whether changed paths need the schema suite | `spec_checks_required` | `tool/hooks/lib.sh` | staged pre-commit and every unpublished pre-push commit |
| Run the schema suite, and fail if schemas exist without it | `check_spec` (isolated stdin) | `tool/hooks/lib.sh` | hooks and `tool/check.sh` |
| Visual regression for the phase 0 scene | Flutter `matchesGoldenFile` against `probes/phase0/test/goldens/`; `probes/phase0/evidence/` stays historical; exact pixels and no second comparator | `probes/phase0/test/determinism_test.dart` | Frames 0 and 59, tag `golden`, on the Linux gate |
| Read encoded presentation times | `frame_pts_ms` and `frame_spacing_ms` over FFmpeg metadata | `probes/phase1/tool/inspect_story.py` | Flash, tone and observed frame spacing |
| Validate draft upstream capture fixes | Disposable package copies plus baseline/patched assertions | `probes/phase1/tool/check_upstream_capture.py` | `probes/phase1/test/upstream_patch_test.dart` |
| Validate local Story jobs | Synchronous `json_schema` plus semantic time/file checks | `flutter/social_studio/lib/src/story_job.dart`, `spec/desktop-story/` | Desktop CLI and composition compiler |
| Compile a photo Story or sequence | `buildStory` over existing Fluvie widgets | `flutter/social_studio/lib/src/story_composition.dart` | `tool/capture_story.dart` in the package |
| Capture desktop frames | Fluvie `renderVideo` and the existing Roboto fixture | `flutter/social_studio/tool/capture_story.dart` | Desktop render command |
| Order photo scenes | Fluvie `Scene` and `Video` offsets, with exact frame durations and default hard cuts | `flutter/social_studio/lib/src/story_composition.dart` | `example/sequence.json` and the real-renderer sequence test |
| Generate synthetic sequence media | Existing phase 1 audio generator and PNG chunk writer | `flutter/social_studio/tool/generate_sequence_assets.py` | Desktop sequence example |
| Review an exported Story | Native HTML video controls, normalized job timing and escaped caption text | `flutter/social_studio/lib/src/story_review.dart`, `assets/review.html` | Desktop export `review.html` |
| Export supplied subtitles | `StoryJob.toSrt()` | `flutter/social_studio/lib/src/story_job.dart` | Capture parser and export `captions.srt` |
| Freeze validated render input | `StoryJob.writeSnapshot` with rebased media references and validated configuration | `flutter/social_studio/lib/src/story_job.dart` | Desktop CLI capture subprocess |
| Detect changed render media | Existing `crypto` SHA-256 in bounded chunks, retained by validated `StoryJob` | `flutter/social_studio/lib/src/story_job.dart` | CLI before capture and final directory rename |
| Check desktop platform projections | `desktop_story_limit_errors`, reusing the v0 duration conversion | `spec/tool/validate_spec.py` | Schema suite invoked by repository and staged spec checks |
| Reject remote image, video, audio, font and transcript references before access | `rejectRemoteReference`, shared by job loading, font reading and caption compilation | `flutter/social_studio/lib/src/story_job.dart` | `flutter/social_studio/test/privacy_boundary_test.dart` |
| Detect an intentional network fetch | Fluvie `NetworkAllowlist` with no hosts, applied by `resolverScope` | `flutter/social_studio/tool/capture_story.dart` | `flutter/social_studio/test/privacy_boundary_test.dart` |
| Strip copied location and device metadata | `storyDiscardedMetadataArguments` on the desktop encode and cover commands | `flutter/social_studio/lib/src/story_encode.dart` | `flutter/social_studio/test/privacy_boundary_test.dart` |
| Advance the desktop capture host at the validated video FPS | `captureFramePump`, with rounded absolute timestamps and a fresh closure per render | `flutter/social_studio/tool/capture_frame_pump.dart` | `tool/capture_story.dart`; real native-ticker pixel regression in `test/capture_frame_pump_test.dart` |
