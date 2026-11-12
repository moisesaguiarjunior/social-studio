# 0006 — Ordered photo scenes in the desktop job

Status: implemented locally for review.
Date: 2026-11-12.

## Context

The next usable increment lets one Story contain several photos. The published
Fluvie renderer already owns scene offsets, scene-local motion and global
captions. Searches covered `Scene`, `Time.frames`, transition defaults,
`Video.sceneStartFrames`, the existing phase 1 three-scene composition and the
reuse map. A second timeline or capture engine is unnecessary.

## Decision

Extend the unpublished desktop job with `scenes`, mutually exclusive with `image`.
The existing single-image form normalizes to one scene. Schema owns the array
shape and authoring limit; semantic validation requires whole-frame durations
summing exactly to the authored total, and validates every local image before
capture. Compile directly to Fluvie scenes with exact frame counts and its
existing hard-cut default. Keep captions, cover and audio on global job time.

Reuse: canonical scene offsets, Ken Burns motion, SRT parsing, capture, muxing
and the existing synthetic PNG/audio helpers. Create: the scene input contract,
normalization, sequence example and regression checks for cuts and captions.

## Alternatives and consequences

Overlapping transitions would alter scene offsets and total duration, so they
remain outside this increment. No general timeline schema or transition engine
is introduced. The unpublished schema accepts more jobs while every previously
valid single-image job keeps its meaning. The unpublished Dart model exposes
normalized scenes instead of a single `imagePath` field. Phone execution and
upstream capture-patch adoption are separate decisions.

## Evidence

`test/story_sequence_test.dart` runs the existing renderer against synthetic
colored photos and observes cut boundaries and caption ink on captured frames.
The full-size runnable example is `example/sequence.json`. Validation and local
execution evidence are recorded in `docs/verification/desktop-story.md`.
