# 0003 — Schema v0 layout and versioning

- Status: accepted
- Date: 2026-11-11

## Context

Phase 2 starts with the language-neutral documents from decision 0001: platform profiles, templates, and render jobs. Flutter and a later React renderer both have to read the same files. `docs/platform-requirements.md` is the research input. It is not a schema, and it keeps cells that the official pages do not fill.

Two version questions follow. A platform can change a number without changing the shape of a document. A document can also gain a field. A consumer has to reject a shape it does not implement, and it has to accept a new number in a shape it does implement.

## Decision

- The documents are JSON Schema draft 2020-12. The dialect is current and has `$defs`, `if`/`then`, and `additionalProperties`. The files live in `spec/schemas/v0/`. `$id` is a URN, `urn:social-studio:schema:v0:…`. No public host name is invented for it.
- Every document carries `schema_version` with const `"0"`. A consumer validates a document with the schema it implements. An unknown version fails that const, so the consumer rejects the document. It does not guess.
- `additionalProperties` is false. A new field, a removed field, a renamed field, or a field that becomes required is a new schema version: a new directory `spec/schemas/vN` and a new const. Documents that still say `"0"` keep validating against v0.
- A changed data value is not a new schema version. Twenty seconds becoming thirty seconds is an edit inside the profile, with the same `schema_version`. `checked_on` is a date pattern, not a fixed date, so a later check of the same page is not a schema bump.
- A limit is `published` or `not_published`. `not_published` forbids `value`, `binding`, and `unit`. `required` is the only binding that can reject a job, and it requires a `value`. `recommended`, `should`, and `can_be` are recorded and are not reject lines. They may omit a number.
- The checker is `spec/tool/validate_spec.py`. It uses the Python 3 standard library (3.9 or newer) and implements only the keywords these schemas use: `$ref` (to `#/$defs/` only, and with no sibling keyword), `allOf`, `anyOf`, `oneOf`, `not`, `if`/`then`/`else`, `const`, `enum`, `type` (including an array of types), `properties`, `required`, `additionalProperties`, `items`, `minItems`, `minLength`, `minimum`, `maximum`, and `pattern`. `$schema`, `$id`, `$defs`, `$comment`, `description`, and `title` are ignored. Any other keyword fails the check. The `integer` keyword follows the draft: a number with a zero fractional part is an integer, and a boolean is not.
- An image, video, or audio slot is filled with an asset id. A text slot is filled with text. A layer of one of those kinds must name a slot of the same kind. A caption cue ends after it starts. Referencable ids are unique: slots, colors, motion presets, and layers. Two layouts with the same profile, path, and surface are not. A layout that names no surface is the generic fallback and may sit beside a layout that names a surface for that same profile and path. `cover_at_ms` is not compared with the job duration. How a renderer trims the timeline, or which frame it uses as a cover, is not a v0 reject and has to be decided before a consumer relies on it.
- v0 rejects a job for duration in seconds, width, height, frame rate, the aspect class `square_or_vertical`, and the token lists `video_codecs`, `containers`, and `accepted_formats`. A required token list rejects a job that names no matching field. File size stays in `MB` or `GB` and is not converted to bytes. Aspect ratios written as ratios, bitrate, audio, color, pixel format, scan, MIME type, fast start, and a moov-atom rule are finished-file checks. They are stored and are not byte or pixel tests on the job. A required published limit id that is neither a job check nor a finished-file check fails the catalog.
- Profiles are the README targets only. The share hand-off and the publishing API are separate paths (`product_hand_off` and `publishing_api`). When a path publishes surfaces, a job names one. Tokens are lowercase, and the API token `hevc` is not an alias of the share token `h265`.
- One template holds the layers once. Layouts are the per-profile canvases. The phase 1 Story is `template/story-12.json` and `render-job/phase1-story-12.json` against Instagram Story `share_hand_off` on Android. The same template has a feed layout.

## Alternatives

- Draft-07. Rejected: draft 2020-12 is the dialect these documents actually use, including `if`/`then` and `$defs`.
- Dart classes as the spec. Rejected: a later React renderer has to read the same files without Flutter.
- Treating every sentence on a platform page as a reject line. Rejected: recommended, should, and can-be would become gates the page did not publish, and a not-published cell would gain an invented number.
- Depending on a third-party JSON Schema library. Rejected for v0: the checker only needs the keywords listed above, and the spec gains no package dependency. The checker does not claim to implement the whole draft.

## Consequences

- A renderer is not part of this decision. Neither are share helpers or conformance frames.
- A profile edit that only changes a published number, a check date, or a source does not bump `schema_version`. An edit that adds a field does.
- A consumer that implements v0 rejects `"schema_version": "1"` because validation fails. Shipping v1 does not rewrite v0 documents.
- `tool/check.sh` runs the schema suite. The Quality workflow calls that entry point, so a checkout with schemas is covered there. The commit hook runs the suite when a staged path is under `spec/`. The push hook runs it for each newly published commit that changes a `spec/` path. Paths are NUL-delimited. A snapshot that has `spec/schemas` and no `spec/tool/test_validate_spec.py` fails the check. A tree with no schemas does not run the suite. `check_spec` closes standard input, so the suite cannot read a caller's ref list. This decision does not claim that a remote workflow run has been observed.
- Required limits are job checks or finished-file checks. The job checks are duration, width, height, frame rate, `aspect_class`, `video_codecs`, `containers`, and `accepted_formats`. The finished-file checks are `aspect_ratio_range`, `audio_channels`, `audio_codecs`, `audio_sample_rate`, `color_space`, `fast_start`, `maximum_file_size`, `mime_types`, `pixel_format`, `scan`, and `video_bitrate`. v0 still does not convert file size to bytes or inspect bitrate, audio, color, pixel format, scan, MIME type, or a moov atom.
- The repository phase 1 window of 10–15 seconds is not encoded as a platform limit. The fixture is 12 seconds. The published Story share maximum remains 20 seconds, and that page publishes no minimum.
- Where two share pages agree, one limit records one URL and names the other page in `text`. The Reel share duration does this for the Android and iOS pages.

## Evidence

Searched `docs/reuse.md` and the repository for an existing schema or validator before adding one. The reuse map had no rows. Nothing in the tree validated JSON Schema. The research input remains `docs/platform-requirements.md`, checked 2026-11-11, and this decision does not edit it. X and WhatsApp are in that document and are not v0 profiles.

The tests in `spec/tool/test_validate_spec.py` cover a valid catalog and the rejects: a duration past a required maximum, an unknown profile, an unfilled slot, and a not-published limit that carries a value, a binding, or a unit. They also keep a recommended value, a should-duration, and a can-be duration from becoming reject lines. A Story share job that names no codec is rejected. A layout for one surface is not used for another surface of the same path. A required limit id outside the two groups fails the catalog.
