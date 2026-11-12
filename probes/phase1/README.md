# Phase 1 Story spike

Synthetic check for one Instagram Story. Nothing here is a product renderer,
and nothing here is published (`publish_to: none`). The measurements are
in `docs/phase1-spike.md`.

The scene is `lib/story_12.dart`: twelve seconds, 1080×1920, 30 fps. A dark
lead-in, a full-frame white flash, a generated tone authored to start with
that flash, a synthetic still that scales slowly, burned-in captions from
`assets/transcript.srt`, and a cover frame at three seconds.

```sh
flutter test
```

The timeline test fails when the scene is not 1080×1920 at 30 fps for 360
frames, when the tone and the transcript are not the ones the scene
declares, or when the scene does not declare the synthetic still. The
inspector test fails when `tool/inspect_story.py --self-check` fails, when
a run that cannot find `ffmpeg` reports success, when a real tone is
described as a 20 ms window, or when a decoded gold frame and a decoded
blue frame count the same swatch pixels. It also builds short clips
and runs the `story_pixels` decision on each. A clip whose color passes
the red and green limits and fails only the blue limit is rejected. A
clip without caption ink is rejected. A clip with caption ink only at
three seconds is rejected. A clip whose swatch does not move is rejected.
A clip with the swatch, its motion, and caption ink at both sampled times
has to pass.

## Generate the synthetic media

```sh
python3 tool/generate_story_assets.py
```

The swatch and the tone are gitignored. Do not commit them, the encoded
video, or a poster. The tone is twelve seconds. `fluvie` 0.3.1 encodes
with `-shortest`, so a one-shot that ends first would cut the video to
the tone.

## Headless render

Run this from `probes/phase1`. `fluvie` is `fluvie_cli` 0.3.1. Set
`FLUVIE_FFMPEG` to a local binary so the CLI does not download one. GPL
FFmpeg is a separate process, as in `docs/decisions/0002-ffmpeg-in-developer-tools.md`.

```sh
fluvie render lib/story_12.dart --out out/story12.mp4 --poster 3s
python3 tool/inspect_story.py out/story12.mp4
```

`tool/inspect_story.py` reuses `probes/phase0/tool/inspect_story15.py` for
the container reading, then measures the flash-to-tone offset in
milliseconds. A positive offset means the tone is later than the white
flash. The tone time is the start PTS of the first audio frame whose
overall RMS reaches −50 dB. The script prints that frame's measured
spacing. It does not treat `astats`'s `length=0.02` as the window.
Sharing to Stories does not publish a sync tolerance. The same command
decodes the frames at three and eight seconds and fails when the swatch
sentinel, the change between those frames, or the caption ink is missing.
If `ffprobe` runs and fails, that failure is returned. If `ffmpeg` is
missing, or the offset cannot be measured, the script exits 1.

## On-device functional check

`integration_test/render_story_test.dart` encodes the same scene with
`OnDeviceVideoRenderer` from `fluvie_mobile_encoder` 0.3.1. The default
codec is H.264, and `audio: true` muxes the tone. `android/` is only the
host that lets that test build. It is not a product app. Run the test on
an Android emulator after the assets exist. `flutter test` does not run
`integration_test/`, so the pre-commit hook does not need a device.

`fluvie` 0.3.1 pre-resolves images on this path and does not pre-resolve
captions. The test calls `preResolveCaptions` on a resolver from
`resolverScope` and passes that resolver in. Without that, every frame
throws while building the caption layer and the test keeps no file.
That call is part of the test. An application on 0.3.1 does not make it,
so the aspect path still throws on the caption layer.

`fluvie` 0.3.1 resolves motion in a post-frame callback. Until that
callback runs, an animated child is painted at opacity 0. The default
off-screen host never drains the callback, so the background and the
captions paint and the still does not. The test passes a capture host
that drains the callback once after mount. The host throws unless the
binding is the live test binding, so the drain does not run in an
application. It does not change `fluvie`. On 0.3.1 the missing caption
pre-resolve and the undrained motion callback are two gaps to fix
upstream or to wrap in a thin package beside `fluvie`.

The test prints `PHASE1_FILE` and `PHASE1_BYTES`. It copies the finished
file into the platform temporary directory and fails if that copy fails.
The encode sandbox is not the directory a host lists. On Android the
platform temporary directory is the code cache, so the test also copies
the file into the app cache and pauses before it returns. The test
uninstalls the host when it finishes. Copy `cache/phase1-story12.mp4`
off the emulator during that pause and inspect it with the same command
as the headless file.

The test also reads the captured raw frames. It fails when the swatch
sentinel is missing at three or eight seconds, when the center of the
still does not change between those times, or when either cue leaves no
caption ink. A file that only has an `ftyp` box is not a pass. This run
is not a P1, D2, or on-device quality result. Those stay not verified
until phones are available.

## Known limits

The Lottie clock and iOS in-composition video clips stay out of scope.
`docs/evaluation.md` records both.
