# Phase 0 probes

Synthetic checks for the evaluation in `docs/evaluation.md`. Nothing here is a
product renderer, and nothing here is published (`publish_to: none`).

```sh
flutter test
```

The inspector controls supply the complete child-process environment, so a
parent terminal's `FFPROBE` or `FLUVIE_FFMPEG` must not change their outcome.
Check the missing-tool case with a deliberately invalid parent override:

```sh
FFPROBE=not-a-real-probe flutter test test/inspect_story15_test.dart --plain-name 'a missing ffprobe stays a partial inspection'
```

`PHASE0_EVIDENCE` may point at a directory. The determinism test then writes
`frame0.png`, `frame59.png`, and `sha256.txt` there. The copies under
`evidence/` are from the run recorded in the evaluation.

The 15-second encode used the published `fluvie_cli` 0.3.1. The scene is
`lib/story_15.dart`. The timed run kept that scene in a throwaway directory
with absolute asset paths. This copy uses package-relative paths. The FFmpeg
binary and the encoded video are not stored in this repository.

```sh
python3 tool/generate_story15_assets.py
fluvie render lib/story_15.dart --out out/story15.mp4 --poster 0s
python3 tool/inspect_story15.py out/story15.mp4
```

Run the render from this directory. `fluvie` is `fluvie_cli` 0.3.1. Set
`FLUVIE_FFMPEG` to a local binary so the CLI does not download one. The
generated harness also needs `flutter_test` and `alchemist` (both dev
dependencies; `alchemist` 0.14.1 is MIT). `tool/inspect_story15.py` prints
the file size and whether `moov` precedes `mdat`. Codec, pixel format, and
color tags are printed when `ffprobe` succeeds. If no `ffprobe` is available
the inspection is partial and the script exits zero. If `ffprobe` runs and
fails, the script exits with that status.
