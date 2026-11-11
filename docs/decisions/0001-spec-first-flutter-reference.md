# 0001 — Language-neutral spec first, Flutter reference renderer

- Status: accepted
- Date: 2026-11-11

## Context

The project must serve Flutter mobile apps that render personal content on the device, and should be reusable by other stacks (React/TypeScript in particular), where most programmatic video tools live (Remotion, Motion Canvas, Revideo).

## Decision

- Everything that does not depend on a language is an open, versioned JSON specification in `spec/`: platform profiles, template format, render jobs and a conformance suite.
- The reference renderer is Flutter, rendering on the device by default. A React/TypeScript renderer may follow if there is demand and must pass the same conformance suite.
- Do not build a video engine from scratch before evaluating existing ones (phase 0: Fluvie, Lottie, encoder packages).
- License: Apache-2.0. No GPL/AGPL dependencies in distributed packages.

## Consequences

- Two renderers would need a conformance suite to stay visually consistent; until there is a second renderer, the suite still documents expected output.
- Contributors from other ecosystems can start with the spec and platform profiles without Flutter.
