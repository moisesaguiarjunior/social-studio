# Social Studio desktop v0.1

A runnable local workflow: a JSON job plus photos, audio and timed text become
`story.mp4`, `cover.png`, `captions.srt`, `review.html` and `result.json`. This checkout tool uses Fluvie's
headless capture, with a fixed photo-sequence/motion/caption template; no mobile patch
or published package is required.

## Run the synthetic example

Prerequisites: Flutter/Dart as pinned by repository CI, Python for the existing
asset generator, and an installed FFmpeg with the libx264 and AAC encoders.
FFmpeg remains a separate developer process under decision 0002; nothing
is downloaded during rendering.

From the repository root:

```sh
python3 probes/phase1/tool/generate_story_assets.py
cd flutter/social_studio
flutter pub get --enforce-lockfile
dart run bin/social_studio.dart validate example/story.json
dart run bin/social_studio.dart render example/story.json out/my-story
```

Choose a new output directory for each render. To select an existing FFmpeg
binary, set `FLUVIE_FFMPEG`. The generated media are gitignored. Supply only
content you are authorized to render; the tool does not decide authorization.

## Review and use the export

Open `review.html` in the output directory. The page plays the encoded video,
lets you select a scene or caption to inspect that moment, and links to the
video, cover and SRT files. It works locally with all files kept together;
there is no upload, remote script, font download or analytics. Playback needs
a browser with H.264/AAC support. If that browser cannot play it, open the MP4
in a local video player.

Scene/caption selection pauses and seeks the video. The SRT retains the supplied
times, while navigation follows the renderer's quantized caption frames.
The page does not edit the job or change the video. Captions are already burned
into the MP4; use the separate SRT when another workflow needs subtitle data.
The validated job, profile, template and validation schemas are frozen into
private temporary files for capture. Editing the source JSON during a render
does not change that export. Media bytes remain referenced local files. SHA-256
checks before capture and before publishing the final directory reject persistent
changes since validation. This detects changes; it is not a filesystem snapshot
and cannot detect a temporary replacement restored between checks. Temporary snapshots are cleaned with
the capture workspace and are not exported. Input media paths are not included. The result manifest lists relative output
files and follows `spec/desktop-story/story-result.schema.json`.

## Render a sequence of photos

From this package directory:

```sh
python3 tool/generate_sequence_assets.py
dart run bin/social_studio.dart validate example/sequence.json
dart run bin/social_studio.dart render example/sequence.json out/my-sequence
```

The generator writes three synthetic images under the ignored `out/` directory
and reuses the existing synthetic audio generator. Replace `image` with `scenes`
in your job to author a sequence:

```json
"scenes": [
  {"image": "first.png", "durationMs": 4000},
  {"image": "second.png", "durationMs": 8000}
]
```

Supply either `image` or `scenes`, never both. One to twelve scenes are accepted;
this is an authoring limit. Each scene must contain a whole number of frames,
and scene durations must sum to the job's `durationMs`. Photos fill the canvas
and zoom independently, with hard cuts. Captions, audio and `coverMs` remain on
the global job timeline: a caption may span a cut and the cover may select any
scene. The existing single-image JSON remains supported.

## Job and template

`example/story.json` shows the complete job. Image and audio paths are relative
to that JSON file. PNG/JPEG and RIFF/WAVE inputs are supported. Remote URLs,
absolute paths, missing files and other signatures are rejected. The validation
command checks the contract and signatures; full decoding occurs during render.
Captions are supplied text with start/end milliseconds, ordered without overlap.
Boundaries use Fluvie 0.3.1's `round((milliseconds / 1000) * fps)` conversion,
including its floating-point operation order; intervals that collapse to zero frames
are rejected so accepted captions cannot silently disappear.
No transcription service is called. The cover selects a frame inside the video.

The versioned schemas, profile and template are canonical in `spec/desktop-story/`.
The profile's canvas/fps and the template's typography, colors, zoom and inset
are data. The inset is a design choice, not a platform safe-zone claim.
Cross-field timing and local-file checks supplement JSON Schema validation.
Unsupported fields/versions are errors rather than silently ignored options.

The template fills each scene with its photo, applies a slow zoom and
burns in supplied captions. Audio starts at zero, is padded with silence when
short and trimmed when long; it cannot truncate the authored video. The cover
is extracted from the encoded output. Source metadata is not forwarded:
photo pixels are decoded/rasterized, and FFmpeg maps only the selected video
and audio streams with metadata/chapter copying disabled.

## Boundaries

This is a checkout-based desktop developer tool, not a published SDK or an
on-device renderer. It reuses the existing local Roboto fixture and license.
The capture harness runs `flutter test --no-pub`, suppresses Flutter analytics
and configures Fluvie's media allowlist with no permitted hosts. The encoder
accepts only file/pipe protocols for the local audio input. These controls are
for this fixed job path; there is no OS-level sandbox for arbitrary code,
network filesystems or native plugins. Forced termination may leave temporary
files; ordinary capture/encode failures clean staging and expose no final output.

No actual Instagram share, phone benchmark or platform acceptance is certified.
The format covers a photo sequence and supplied captions; general template
editing, transition effects, music selection and mobile sharing remain roadmap work.

## Library surfaces

- `package:social_studio/social_studio.dart`: load/validate local jobs.
- `package:social_studio/rendering.dart`: compile a validated job to a Fluvie
  composition, using a local SRT generated by `StoryJob.toSrt()`.

Both use the canonical spec supplied by the checkout. Run `bash tool/check.sh`
from the repository root for formatting, analysis and tests.
