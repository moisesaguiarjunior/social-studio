# Social Studio — Flutter social video rendering

[![Version: 0.1.0 (unpublished)](https://img.shields.io/badge/version-0.1.0%20%28unpublished%29-blue)](flutter/social_studio/CHANGELOG.md)
[![CI](https://github.com/moisesaguiarjunior/social-studio/actions/workflows/quality.yml/badge.svg)](https://github.com/moisesaguiarjunior/social-studio/actions/workflows/quality.yml)
[![Coverage](https://codecov.io/gh/moisesaguiarjunior/social-studio/graph/badge.svg)](https://codecov.io/gh/moisesaguiarjunior/social-studio)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-purple.svg)](LICENSE)

Social Studio (`social-studio`) is an open-source Flutter/Dart project for
programmatic social media video generation. Its desktop CLI turns local photos,
WAVE audio and supplied timed captions into an Instagram Story MP4, a cover
image, SRT subtitles and an offline HTML review page. Rendering uses Fluvie;
platform profiles, templates and render jobs are versioned JSON specifications.

The longer-term goal is **finished, ready-to-post pieces with art direction**
for Instagram Stories and feed posts, Reels, TikTok, YouTube Shorts and
horizontal YouTube videos. These additional render targets remain roadmap work.

[Quick start](#quick-start) · [Current capabilities](#current-capabilities) ·
[Documentation](#documentation) · [Architecture](#architecture) ·
[Roadmap](docs/roadmap.md) · [Contributing](CONTRIBUTING.md)

## Quick start

```sh
python3 probes/phase1/tool/generate_story_assets.py
cd flutter/social_studio
flutter pub get --enforce-lockfile
dart run bin/social_studio.dart validate example/story.json
dart run bin/social_studio.dart render example/story.json out/my-story
```

Requires a local Flutter SDK and FFmpeg with libx264/AAC. The output directory
must be new. The example uses synthetic content; replace the relative image,
audio and timed caption fields in the JSON to render authorized local content.
For several photos with individual durations, use the
[sequence example](flutter/social_studio/README.md#render-a-sequence-of-photos).
See [inputs, validation and limitations](flutter/social_studio/README.md).

## Current capabilities

| Capability | Status and entry point |
| --- | --- |
| Local JSON-to-MP4 rendering | Implemented for desktop: [CLI usage](flutter/social_studio/README.md) |
| One photo or a photo sequence, slow zoom and hard cuts | Implemented: [sequence example](flutter/social_studio/README.md#render-a-sequence-of-photos) |
| Supplied captions, local audio, cover and review page | Implemented: [export artifacts](flutter/social_studio/README.md#review-and-use-the-export) |
| Platform profiles and general catalog schemas | Validated data: [specification](spec/README.md); general catalog rendering is pending |
| Android/iOS rendering, sharing and performance | Pending device acceptance: [evaluation](docs/evaluation.md) |
| Reel, TikTok, Shorts, feed and horizontal video rendering | Planned after the device gate: [roadmap](docs/roadmap.md) |

This is a checkout-based developer tool, version 0.1.0, not a pub.dev release.
The coverage badge reports the desktop package's library tests, not phone
coverage, the probes or complete subprocess execution. It needs a successful
Codecov upload before it can display a percentage.

## Documentation

Start with the [documentation index](docs/README.md) for task-based navigation,
canonical contracts and a search map for people and coding assistants.

- **Use the CLI:** [desktop guide and API surfaces](flutter/social_studio/README.md).
- **Understand the formats:** [JSON Schema contracts](spec/README.md).
- **Assess readiness:** [execution roadmap](docs/roadmap.md) and [desktop verification](docs/verification/desktop-story.md).
- **Contribute safely:** [contribution standards](CONTRIBUTING.md), [reuse map](docs/reuse.md) and [technical decisions](docs/decisions/).

## Goals

1. **Finished output, not raw export.** Each piece follows the target platform's format and safe zones, has a cover, captions, motion and art direction, and a suggested post text.
2. **On-device by default.** Rendering runs on the user's phone, so private content (for example, family photos and voices) never needs to leave the device. Server or desktop rendering is optional, for the same templates.
3. **Reusable core.** Everything that does not depend on a programming language is an open JSON specification: platform profiles, template format, render jobs and a conformance suite.
4. **Flutter first, React later.** The reference renderer is Flutter, because the first consumers are Flutter apps. A React/TypeScript renderer may follow and must pass the same conformance suite.

## Non-goals

- Posting automatically to social networks. The app hands a finished file to the platform (official sharing intents or the system share sheet); the person posts.
- Bundling copyrighted music. Audio comes from the user's content (for example, a recorded voice) or from permissively licensed tracks. People can add music through the platform's own library after exporting.
- Deciding what may be shared. The consuming app decides; the engine only receives content that was already authorized.
- Building a video engine from scratch before evaluating existing ones.

## Architecture

```text
spec/                      language-neutral, versioned JSON Schemas
  platform-profiles        formats, sizes, durations, safe zones, caption rules per platform
  template                 layers, timing, text, media slots, brand tokens, motion
  render-job               template + data + target profile -> expected output
  conformance/             reference jobs with expected frames and tolerances
flutter/                   reference renderer (packages), on device and headless
react/                     later, if there is demand
```

### Platform profiles (to be filled from official sources)

| Target | Aspect ratio | Notes to verify and cite |
| --- | --- | --- |
| Instagram Story | 9:16 | Sharing to Stories accepts a background video up to 20 s at up to 1080p; stickers must be images ([Meta docs](https://developers.facebook.com/docs/instagram-platform/sharing-to-stories)) |
| Instagram Reel, TikTok, YouTube Shorts | 9:16 | Durations, file limits and **UI safe zones** differ per platform and change over time |
| Instagram feed post / carousel | 4:5 and 1:1 | Image and video limits |
| YouTube video | 16:9 | Resolution, length, cover image |

Every number entered in a profile needs the official source and the date it was checked. Profiles are data, versioned, so a platform change is a data update, not a code change.

### Template format (to design in phase 2)

A template declares: canvas per target profile, layers (image, video, text, shape, Lottie animation), timing, media slots filled by data (`photo[0]`, `voice`, `quote`), brand tokens (colors, fonts, logo), motion presets and caption style. The same template should produce coherent output for several profiles (for example, Story and feed post) by layout rules, not by duplication.

## Privacy and safety

- No network access during rendering. No analytics on content.
- Strip location and device metadata from outputs.
- Fixtures, examples, goldens and the conformance suite use synthetic data only. Never real people's photos, voices or transcripts.
- Captions come from a transcript supplied by the app; the engine never sends audio to a third party.

## Licensing

Apache-2.0. Distributed packages must not depend on GPL/AGPL code. Record the license of every dependency (and of any binary a tool downloads) in `docs/dependencies.md`.

## Phases

### Phase 0 — Evaluation (first task)

Evaluate, with the criteria below written **before** testing:

| Candidate | Role |
| --- | --- |
| [Fluvie](https://pub.dev/packages/fluvie) (+ `fluvie_mobile_encoder`, `fluvie_cli`, `fluvie_web_encoder`) | Programmatic video in Flutter: scenes, on-device encoding, headless rendering, audio mixing |
| Lottie (Flutter `lottie` package; web/React players) | Art and motion authored by designers, with dynamic text and images |
| [widget_recorder_plus](https://pub.dev/packages/widget_recorder_plus), [flutter_quick_video_encoder](https://pub.dev/packages/flutter_quick_video_encoder) | Fallback building blocks if Fluvie does not fit |

Criteria:

1. Licenses of every package and downloaded binary (including any FFmpeg build used by the CLI).
2. Determinism: same job renders the same frames across runs, and headless vs on-device differences are measured.
3. Quality: text sharpness, color, motion smoothness at 1080x1920.
4. Performance: time to render a 15 s 1080x1920 piece on a mid-range Android phone and on an iPhone (report numbers; targets are set by the maintainers).
5. Gaps: video clips inside compositions on iOS (reported as unimplemented on device), audio mixing, captions.
6. Health: maintenance activity, tests, issue response, ease of contributing.

Deliverable: `docs/evaluation.md` with results, evidence (commands, devices, versions) and a recommendation: adopt and contribute, adopt partially, or fork.

### Phase 1 — Spike

One Instagram Story, 9:16, 10–15 s: one photo with slow motion, a recorded voice track, captions from a supplied transcript, a cover frame. Rendered on an Android device and headless; golden frames committed; file passes the Stories sharing limits.

### Phase 2 — Core v0

JSON Schemas for platform profiles, templates and render jobs (with validation tests); Flutter renderer for Story/Reel/TikTok/Shorts (9:16), feed (4:5, 1:1) and YouTube (16:9); share helpers (Instagram Stories intent, system share sheet); first conformance jobs.

Schema v0 and its validation tests are in `spec/`. Share helpers and general
v0 catalog rendering remain unimplemented.

See [the execution roadmap](docs/roadmap.md) for the ordered desktop work,
implemented milestones and the remaining device acceptance gate.

## Consumers

The first consumers are mobile apps built with Flutter, where the content is personal and sharing is always the user's explicit choice. Each consuming app enforces its own rules about what may be shared before calling the engine.

## Contributing

Issues and pull requests are welcome once phase 0 is published. Read [CONTRIBUTING.md](CONTRIBUTING.md): the code standards, local review hooks and independent review apply to human and AI contributors alike. By contributing you agree that your contributions are licensed under the [Apache License 2.0](LICENSE).


## Repository checks

Run `bash tool/check.sh` from any directory to check the checkout: hook
regressions, schema validation, then format, strict analysis and tests for
each Dart/Flutter package. The Quality workflow uses the same entry point,
SDK version 3.47.9 and Python 3.12. It runs on every pull request and pushes
to main; there are no workflow path filters that could leave a required
check pending.

Local hooks still check snapshots: staged content at commit time and every
newly published commit before push. Tool/workflow changes also run hook
regressions, and `spec/` changes run the schema tests, even when no package
owns the file. Independent local review is still required before any branch
is pushed. See [verification and limits](docs/verification/repository-gates.md).

Collect desktop library coverage with `bash tool/coverage.sh`. The separate
[Coverage workflow](.github/workflows/coverage.yml) uploads the LCOV report to
Codecov; it does not replace the Quality checks or impose a percentage gate.
See [coverage scope and setup](docs/verification/coverage.md).
