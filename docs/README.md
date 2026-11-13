# Social Studio documentation

Social Studio is a Flutter/Dart project for programmatic social video rendering.
The runnable desktop CLI accepts local JSON Story jobs and exports MP4, a PNG
cover, supplied SRT captions and an offline HTML review page. The mobile-first,
multi-platform engine is the destination; see the roadmap for unfinished work.

## Start with a task

| I want to… | Read |
| --- | --- |
| Render a Story from local photos, audio and captions | [Desktop quick start and CLI reference](../flutter/social_studio/README.md) |
| Use multiple photos or inspect an export | [Photo sequences](../flutter/social_studio/README.md#render-a-sequence-of-photos) and [review artifacts](../flutter/social_studio/README.md#review-and-use-the-export) |
| Validate JSON or understand the two input contracts | [Specification guide](../spec/README.md) and [desktop contract decision](decisions/0005-desktop-story-job.md) |
| Find the next implementation milestone | [Execution roadmap](roadmap.md) |
| Assess rendering quality, determinism or mobile readiness | [Evaluation](evaluation.md), [phase 1 spike](phase1-spike.md) and [render validation](verification/render-validation.md) |
| Check privacy protections and their limits | [Desktop boundaries](../flutter/social_studio/README.md#boundaries), [privacy checks](verification/privacy.md) and [desktop verification](verification/desktop-story.md) |
| Cancel a desktop render and understand cleanup | [Cancellation guide](../flutter/social_studio/README.md#cancel-a-render) and [verification](verification/cancellation.md) |
| Run checks or understand coverage | [Repository gates](verification/repository-gates.md) and [coverage](verification/coverage.md) |
| Reuse an implementation or review a design choice | [Reuse map](reuse.md) and [architecture decisions](decisions/) |
| Check platform rules or dependency licensing | [Platform research](platform-requirements.md) and [dependency inventory](dependencies.md) |
| Review documentation accuracy and retrieval choices | [README content review](verification/readme-discovery.md) |
| Contribute code or run an independent review | [Contribution standards](../CONTRIBUTING.md) and [agent instructions](../AGENTS.md) |

## Canonical sources

The documents below have different roles. Follow links to the source instead
of copying a limit, policy or implementation into another file.

- **Current runnable behavior:** the [desktop guide](../flutter/social_studio/README.md), its [tests](../flutter/social_studio/test/) and [verification record](verification/desktop-story.md).
- **Desktop authoring contract:** [spec/desktop-story](../spec/desktop-story/) owns job/result schemas and the fixed template/profile. The desktop CLI does not accept general catalog jobs.
- **General catalog contract:** [spec/schemas/v0](../spec/schemas/v0/) and [spec/platform-profiles](../spec/platform-profiles/) own the broader format and sourced platform requirements. The desktop limit projection is checked against this catalog.
- **Future scope:** the [roadmap](roadmap.md) owns ordering and acceptance criteria. A schema or profile's existence does not imply a renderer or share helper is implemented.
- **Durable technical choices:** [decisions](decisions/) record context, alternatives and consequences. Proposed/historical work must be read with its status.
- **Measured results:** [verification](verification/) and the [evaluation](evaluation.md) identify software, controls and unverified behavior. Historical evidence is not a claim about the current commit.

## Search the implementation

Use these terms with repository search or `rg`. Paths are relative to the root.

| Search terms | Canonical entry point |
| --- | --- |
| `validate`, `render`, MP4, cover, FFmpeg, staging cleanup | `flutter/social_studio/bin/social_studio.dart` |
| `StoryJob`, local assets, caption timing, media integrity, snapshot | `flutter/social_studio/lib/src/story_job.dart` |
| `buildStory`, photo sequence, Ken Burns, hard cuts | `flutter/social_studio/lib/src/story_composition.dart` |
| `buildStoryReview`, review HTML, seek, SRT | `flutter/social_studio/lib/src/story_review.dart` |
| `RenderProcesses`, SIGINT, SIGTERM, cancellation, worker groups | `flutter/social_studio/lib/src/render_processes.dart`, `flutter/social_studio/tool/run_process.py` |
| `runOffline`, HTTP, network boundary | `flutter/social_studio/lib/src/offline_rendering.dart`, `flutter/social_studio/tool/capture_story.dart` |
| `maximum_duration_seconds`, platform limits, schema validation | `spec/platform-profiles/`, `spec/tool/validate_spec.py` |
| hooks, independent review, format, strict analysis | `tool/check.sh`, `tool/hooks/`, `CONTRIBUTING.md` |
| Codecov, LCOV, line coverage | `tool/coverage.sh`, `.github/workflows/coverage.yml` |

## Reading with a coding assistant

Start at [AGENTS.md](../AGENTS.md), then this index and the [reuse map](reuse.md).
Read the actual schema, caller and tests before proposing an implementation.
[llms.txt](../llms.txt) provides a short link directory for tools that use that
convention; it adds no instructions or alternative contracts. Neither that file
nor these edits guarantee external search indexing or AI recommendations.
