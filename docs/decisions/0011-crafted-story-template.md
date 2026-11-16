# 0011: Crafted materials in a versioned desktop template

Status: implemented for independent review.
Date: 2026-11-16.

## Context

The maintainer authorized integration work across handcrafted_flutter, Social
Studio and Fluvie. Existing desktop inputs reject unknown fields; adding material
arguments to version 1 would change its contract. The renderer already owns
photo sequences, captions, offline capture, frozen jobs and atomic export.
Handcrafted supplies bounded material/shape/thread primitives, not that pipeline.

## Decision

Add desktop job/template version 2 under spec/desktop-story/v2, with template
id story-craft-v1. Preserve v1 schemas/data and the shared profile/result format.
The required craft object allowlists material, color, seed, grainScale,
grainStrength, frameInset, edge and stitch. No callback, URL, clock or Dart type
is serialized. These are authoring choices, not platform requirements.

Pin handcrafted_flutter by immutable Git revision, keeping Fluvie hosted 0.3.1.
The adapter implements Fluvie's existing public CollectibleChildren contract:
media remain declared constructor children, visible before mounting. The material
wrapper renders the substrate, clipped photo and decorative border, while Fluvie
retains decoding, motion and captions. A second clock/collector is unnecessary.

Snapshots retain the selected version namespace, schemas, template and recipe.
The CLI uses the same validation, integrity checks, offline capture, metadata
stripping, FFmpeg process, review page and transaction cleanup as version 1.

The initial supported crafted canvas has each side 64..2048 logical pixels and
width + height at most 3072. This conservative renderer envelope reserves the
material/outline/offset work budget and includes the existing authored canvas.
It is not a platform restriction. With stitching enabled, frameInset times the
shorter
canvas side must also be at most 256 logical pixels: the centered seam uses
half that margin and the geometry contract caps its inset at 128. Unsupported
combinations fail validation before composition, without clamping the recipe.
Stitch pitch also reserves room below the
package cell budget for narrow/tall canvases. More output sizes need separate
geometry/resource evidence, not silent clamping of supplied content.

## Alternatives and consequences

Mutating v1 or accepting arbitrary extra fields would hide compatibility changes.
A general template engine or a new media decoder would duplicate existing work.
Adding Fluvie as a dependency of handcrafted_flutter would reverse ownership.
Instead, each package keeps its existing role and the consumer owns the schema.

FrameBuilder remains available for externally driven decorative poses. This
first recipe uses Fluvie's existing photo animation rather than another ticker.
Phone performance, flexible cloth and general catalog compilation stay open.

## Evidence

Tests cover strict v1/v2 validation, frozen recipe replay, material work limits,
real raw-frame capture with pre-resolved media and byte-identical repeated runs,
and the actual CLI producing MP4/cover/SRT/review/result artifacts. Independent
review and its exact commit are recorded in the PR before publication.
