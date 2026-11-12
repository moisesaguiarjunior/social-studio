# 0005 — First usable vertical slice: local Story jobs on desktop

Status: implemented locally for review; not a mobile adoption decision.
Date: 2026-11-12.

## Context

The maintainer requested concrete product progress after validation work.
The pinned headless renderer already captures the Story shape, while mobile
capture patches remain unadopted. Fluvie's VideoSpec does not expose this job's
caption/audio contract; using it as the public job format would also couple the
language-neutral spec to a renderer. Building another engine is unnecessary.

## Decision

Add a checkout-based package at `flutter/social_studio`: versioned JSON jobs
are validated against `spec/desktop-story`, then compiled to the existing Fluvie widgets.
Use synchronous `json_schema` validation (Draft 7), with no remote references.
Reuse the existing font and synthetic asset generator. The only template is
one local photo with slow motion and supplied timed captions. Audio is local
WAVE, muxed by a separate FFmpeg process with explicit padding and duration,
so the upstream `-shortest` behavior cannot shorten the authored piece.

Profile/template numbers live in spec data with provenance or an explicit
statement that they are authoring choices. Cross-field time relations and
local-file existence/signatures are semantic checks, not duplicated schema
structure. No normal dependency override adopts the mobile draft patches.

## Alternatives and consequences

Waiting for mobile adoption would postpone a usable workflow. Creating a broad
editor or general multi-platform template engine now would expand the contract
before a real consumer exists. The small checkout tool produces inspectable
artifacts and supplies that first consumer, but is not ready for package
publication: schema/font resources currently live elsewhere in this repository.
The desktop tool uses a local FFmpeg binary under decision 0002 and does not
bundle or download it. Native codec, sharing and phone performance remain open.

## Evidence

See `flutter/social_studio/README.md` for executable commands. Local rendering
of the synthetic example produces a video and cover. Existing probe/dependency
sources and `docs/reuse.md` were searched for JSON validation, media loading,
caption collection, scene building, capture and output inspection before coding.
The selected validator's synchronous API cannot fetch remote references:
https://pub.dev/documentation/json_schema/latest/json_schema/JsonSchema/create.html
Its package license is Boost-1.0, with MIT-licensed test-suite material:
https://pub.dev/packages/json_schema/license (checked 2026-11-12).

## Relationship to schema v0 and convergence

Decision 0003 reserves `spec/schemas/vN` for successive versions of the general
catalog contract. `spec/desktop-story` is a renderer-specific authoring format,
not schema v1 or a successor to v0. Its `version` field versions only that
format. The desktop runner does not accept general v0 jobs.

The authoritative platform requirements remain in `spec/platform-profiles`.
The desktop maximum duration is a checked projection of Instagram Story's
`share_hand_off` / `maximum_duration_seconds` required published rule, converted
using the existing v0 validator's scale. `tool/check.sh` invokes the schema suite,
which reads both checked-in documents and rejects drift, missing/reclassified
rules and invalid projected values. The same suite runs in the staged spec
commit/push checks. The 10–15 second authoring window remains a product choice.

Convergence will proceed through an explicit catalog-to-renderer adapter:

1. Resolve platform/path/surface and limits from the existing catalog; remove
   projected platform constants from the desktop configuration as the adapter
   becomes the consumer. Retain design choices (crop, motion, typography) in
   template data rather than platform requirements.
2. Map supported catalog layers, slots, asset ids and timing into the existing
   composition builder. Reject unsupported features explicitly. Define local
   asset resolution, caption/cover timing and scene support with shared fixtures.
3. Run the current single-photo/sequence, subtitle, integrity and visual controls
   through both supported entry formats and the same renderer. Remove the
   separate desktop input only through a documented migration after equivalent
   output is verified.

Do not relabel desktop documents as catalog v1. A catalog shape change follows
0003 with a new schema directory, an explicit version and migration evidence.
This plan does not claim the adapter is implemented by the current change.
