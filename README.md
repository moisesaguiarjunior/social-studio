# Social Studio — Flutter social video rendering

[![Version: 0.1.0 (unpublished)](https://img.shields.io/badge/version-0.1.0%20%28unpublished%29-blue)](flutter/social_studio/CHANGELOG.md)
[![CI](https://github.com/moisesaguiarjunior/social-studio/actions/workflows/quality.yml/badge.svg)](https://github.com/moisesaguiarjunior/social-studio/actions/workflows/quality.yml)
[![Coverage](https://codecov.io/gh/moisesaguiarjunior/social-studio/graph/badge.svg)](https://codecov.io/gh/moisesaguiarjunior/social-studio)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-purple.svg)](LICENSE)

Social Studio (`social-studio`) is an open-source Flutter/Dart project for
programmatic social media video generation. Its headless desktop CLI turns local photos,
WAVE audio and supplied timed captions into an Instagram Story MP4, a cover
image, SRT subtitles and an offline HTML review page. It compiles versioned JSON
jobs into Fluvie compositions and uses a local FFmpeg process for encoding.

**Current status:** a checkout-based desktop developer tool, version 0.1.0,
unpublished on pub.dev. Mobile rendering, actual sharing and additional output
formats remain [roadmap work](docs/roadmap.md).

[Quick start](#quick-start) · [JSON input](#json-story-input) ·
[Outputs](#exported-files) · [Capabilities](#current-capabilities) ·
[Architecture](#architecture-and-canonical-contracts) ·
[Documentation](#documentation) · [Checks](#contributing-and-checks)

## Quick start

Prerequisites: a local Flutter SDK, Python 3 and FFmpeg with libx264/AAC.
Use the SDK pinned in the [Quality workflow](.github/workflows/quality.yml).
The CLI neither bundles nor downloads FFmpeg. Start with synthetic content:

```sh
git clone https://github.com/moisesaguiarjunior/social-studio.git
cd social-studio
python3 probes/phase1/tool/generate_story_assets.py
cd flutter/social_studio
flutter pub get --enforce-lockfile
dart run bin/social_studio.dart validate example/story.json
dart run bin/social_studio.dart render example/story.json out/my-story
```

The output directory must be new. Open `out/my-story/review.html` to review the
encoded video. Keep the exported directory together. See the
[desktop CLI guide](flutter/social_studio/README.md) for inputs, errors and
[photo sequences](flutter/social_studio/README.md#render-a-sequence-of-photos).

## JSON Story input

A job supplies local media and timed text; the renderer does not transcribe
speech or choose which content is authorized. Save this as `job.json` beside
your authorized `photo.png` and `voice.wav` files:

```json
{
  "version": 1,
  "template": "story-photo-v1",
  "image": "photo.png",
  "audio": "voice.wav",
  "durationMs": 12000,
  "coverMs": 3000,
  "captions": [
    {"startMs": 1000, "endMs": 5000, "text": "A moment worth keeping"}
  ]
}
```

From the desktop package, run `dart run bin/social_studio.dart validate job.json`
then `dart run bin/social_studio.dart render job.json out/another-story`.
Media paths are relative to the job. PNG/JPEG photos and RIFF/WAVE audio are
supported; times are milliseconds. For multiple photos, use `scenes` instead
of `image`. Unknown keys and unsupported versions fail validation. The complete
contract is [story-job.schema.json](spec/desktop-story/story-job.schema.json);
the runnable fixture is [example/story.json](flutter/social_studio/example/story.json).

## Exported files

| File | Purpose |
| --- | --- |
| `story.mp4` | Encoded video with motion, audio and burned-in captions |
| `cover.png` | A frame selected from the encoded video |
| `captions.srt` | Supplied subtitles for workflows needing a separate file |
| `review.html` | Offline playback with scene and caption navigation |
| `result.json` | Manifest of relative artifact paths and output properties |

The [result schema](spec/desktop-story/story-result.schema.json) owns the
manifest contract. The review page plays the actual export; it is not an editor.

## Current capabilities

| Capability | Status and source |
| --- | --- |
| Local JSON-to-MP4 desktop rendering | Implemented: [CLI guide](flutter/social_studio/README.md) |
| One photo or a sequence, slow zoom and hard cuts | Implemented: [sequence example](flutter/social_studio/README.md#render-a-sequence-of-photos) |
| Supplied captions, local audio, cover and review page | Implemented: [export review](flutter/social_studio/README.md#review-and-use-the-export) |
| General platform profiles and catalog schemas | Validated data: [specification](spec/README.md); catalog-to-renderer adapter pending |
| Android/iOS rendering, sharing and performance | Pending acceptance: [evaluation](docs/evaluation.md) |
| Reel, TikTok, Shorts, feed and horizontal video rendering | Planned: [execution roadmap](docs/roadmap.md) |

The long-term goal is finished pieces with art direction and an on-device
Flutter core, followed by another renderer only if demand justifies it.
The tool does not post automatically, bundle copyrighted music or decide
what a consuming app may share. General template authoring is not implemented.

## Architecture and canonical contracts

Existing directories and their responsibilities:

```text
flutter/social_studio/       desktop CLI, validated jobs and Fluvie composition
spec/desktop-story/          current desktop job, profile, template and result schemas
spec/schemas/v0/             general catalog schemas (separate input format)
spec/platform-profiles/      sourced platform requirements
spec/template/              general catalog template examples
spec/render-job/            general catalog job examples
probes/phase0/              engine evaluation experiments
probes/phase1/              Story rendering experiments
tool/                      repository checks, Git hooks and coverage collection
docs/                      roadmap, decisions, reuse map and verification
```

**The desktop CLI accepts `spec/desktop-story` jobs, not general v0 catalog
jobs.** The two formats are not interchangeable. The catalog is authoritative
for platform requirements; a schema check compares the desktop duration
projection against it. See [the specification guide](spec/README.md) and
[decision 0005](docs/decisions/0005-desktop-story-job.md) for convergence work.
Conformance jobs and a React renderer remain future work, not existing packages.

## Privacy and rendering boundaries

The supported desktop path rejects remote media, font and transcript references.
Capture blocks connections from new Dart HTTP clients and uses Fluvie's empty
media host allowlist. FFmpeg accepts local audio through file/pipe protocols.
Photos are rasterized; encoded video and cover disable source metadata copying.
Fixtures and tests use synthetic content only. No analytics run on content.

These controls do not sandbox existing clients, raw sockets, native plugins,
network filesystems or arbitrary subprocesses. Phone encoder metadata and actual
sharing still need device validation. Read the
[privacy evidence](docs/verification/privacy.md),
[capture-boundary decision](docs/decisions/0009-desktop-http-boundary.md) and
[desktop limits](flutter/social_studio/README.md#boundaries) before integration.

## Documentation

The [documentation index](docs/README.md) maps tasks and search terms to canonical
schemas, code and evidence. Start there to use, extend or assess Social Studio.

- **Use the CLI:** [desktop guide and library surfaces](flutter/social_studio/README.md#library-surfaces).
- **Understand the design:** [architecture decisions](docs/decisions/) and [reuse map](docs/reuse.md).
- **Assess readiness:** [roadmap](docs/roadmap.md), [evaluation](docs/evaluation.md) and [desktop verification](docs/verification/desktop-story.md).
- **Inspect platform rules and licenses:** [platform research](docs/platform-requirements.md) and [dependency inventory](docs/dependencies.md).

For coding assistants, [AGENTS.md](AGENTS.md) owns contribution instructions;
[llms.txt](llms.txt) is an optional link directory, not another specification.
The evaluation and probe records are historical evidence, not release promises.

## Contributing and checks

Read [CONTRIBUTING.md](CONTRIBUTING.md) before changing code. Reuse existing
solutions, run the checks and obtain independent local review before any push.
Changes enter through pull requests; never push directly to `main`.

From the repository root:

```sh
bash tool/install-hooks.sh
bash tool/check.sh
bash tool/coverage.sh
```

`check.sh` runs hook regressions, coverage tooling tests, schema validation,
formatting, strict analysis and each Dart/Flutter package's tests. The
[Quality workflow](.github/workflows/quality.yml) uses the same entry point.
Exact phase 0 golden comparisons run on the pinned Linux CI path; local
platform skips are explicit. See [repository gates](docs/verification/repository-gates.md).

The coverage badge follows uploaded reports for the repository's default branch.
The [Coverage workflow](.github/workflows/coverage.yml) uploads desktop library
LCOV to Codecov. Coverage excludes probes and subprocess execution and has no
percentage gate; it does not certify mobile behavior. See
[coverage scope and setup](docs/verification/coverage.md).

## License

[Apache-2.0](LICENSE). No GPL/AGPL dependencies in distributed packages and no
bundled copyrighted music. The separately installed developer FFmpeg process
follows [decision 0002](docs/decisions/0002-ffmpeg-in-developer-tools.md).
