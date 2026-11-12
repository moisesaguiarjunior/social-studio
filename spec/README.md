# Spec

Language-neutral documents for every renderer. Schema v0 is JSON Schema draft 2020-12 (`https://json-schema.org/draft/2020-12/schema`). That draft is the current one, and it has `$defs`, `if`/`then`, and `additionalProperties`, which this set uses. The schemas are not Dart types. `$id` is a URN (`urn:social-studio:schema:v0:…`). No public domain is invented for it.

| Path | What it is |
| --- | --- |
| `schemas/v0/` | The three schemas: platform profile, template, render job |
| `platform-profiles/` | One document per README target |
| `template/` | Shared layers, and one layout per target |
| `render-job/` | A template, its data, and the profile it renders to |
| `fixtures/` | Examples the catalog does not include. `invalid/` must fail. `valid/` must pass |
| `tool/validate_spec.py` | Checker for the keywords these schemas use |
| `tool/test_validate_spec.py` | The tests |

```bash
python3 spec/tool/test_validate_spec.py
python3 spec/tool/validate_spec.py
```

`tool/check.sh` runs the same suite. The commit and push hooks run it when a path under `spec/` changes. If `spec/schemas` is present and `tool/test_validate_spec.py` is missing, that check fails. A tree with no schemas does not run the suite.

The checker uses the Python 3 standard library (3.9 or newer). It is not a complete draft 2020-12 implementation. An unknown keyword fails the check. Decision [0003](../docs/decisions/0003-schema-versioning.md) records which keywords are implemented, how a version changes, and how a consumer rejects a version it does not know.

## What a profile stores

Each limit has its source URL and the date that page was checked (`checked_on`). Page update dates are `source_updated`, or `not shown` when the page does not display one.

- `not_published` has no `value`, no `binding`, and no `unit`. The absence is the record. A later edit does not invent the number.
- `required` is the only binding that can reject a job, and it has a `value`.
- `recommended`, `should`, and `can_be` are recorded. They do not reject a job, and they may omit a number.
- The share hand-off (`product_hand_off`) and the publishing API (`publishing_api`) are different paths. A file can pass one and fail the other.
- Tokens are lowercase: `h264`, `h265`, `hevc`, `webm`, `mov`, `mp4`, `mkv`, `vp8`, `vp9`. The publishing API's HEVC token is `hevc`. It is not renamed to the share hand-off's `h265`.
- File sizes stay in the unit the page uses (`MB` or `GB`). v0 does not convert them to bytes.
- v0 rejects a job for duration, width, height, frame rate, the Shorts aspect class `square_or_vertical`, and a codec, container, or accepted-format list. A required list rejects a job that does not name the field. These required limits are finished-file checks and are not job rejects: `aspect_ratio_range`, `audio_channels`, `audio_codecs`, `audio_sample_rate`, `color_space`, `fast_start`, `maximum_file_size`, `mime_types`, `pixel_format`, `scan`, and `video_bitrate`. A required limit id in neither group fails the catalog. v0 does not inspect a finished file for those checks.
- When a path has surfaces, the job names one. Path limits apply to every surface. Surface limits are added. The Android 720×1280 Story minimum is an Android surface limit. The iOS video row does not repeat it.
- An image, video, or audio slot is filled with an asset id. A text slot is filled with text. A layer of those kinds names a slot of the same kind. A caption cue ends after it starts. Slot, color, motion, and layer ids are unique. Two layouts that share a profile, a path, and a surface are rejected. A layout with no surface may sit beside one that names a surface.
- `cover_at_ms` is not checked against the job duration. v0 does not say how a renderer trims a timeline or which frame is the cover. That rule is for the consumer, and it is not a platform limit.

The profiles are the README targets only: Instagram Story, Reel, and feed; TikTok; YouTube Shorts and horizontal. X and WhatsApp stay in `docs/platform-requirements.md` and are not profiles yet. That research document is the input. These JSON files do not replace it.

## The phase 1 Story

`template/story-12.json` plus `render-job/phase1-story-12.json` is the phase 1 Story: 12 seconds, a 1080×1920 canvas, H.264, against Instagram Story `share_hand_off` on Android. The same template has a feed layout (1080×1350 on the Android video share path) filled by `render-job/story-12-feed.json`. Layers are shared. Layouts change the canvas.

1080×1920 and 1080×1350 are repository canvases. The Story share page says videos can be 1080p and does not define that pixel size. The feed share table does not publish 4:5; the publishing-API image range that includes 4:5 is a different path. The repository's 10–15 second phase 1 window is not an Instagram limit. The published Story share maximum is 20 seconds, and the page publishes no minimum.

The cover time, the colors, the slow scale, and the two caption cues are the fixture. The cues are a supplied transcript baked into this example template. The voice asset is a synthetic tone used as a sync marker. Nothing in the fixture is a recording of a real person.

## What is not here

A renderer, share helpers, and conformance frames are later work. `spec/conformance/` does not exist yet.
