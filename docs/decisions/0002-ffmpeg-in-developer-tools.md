# 0002 — GPL FFmpeg only as a separate developer-tool process

- Status: accepted
- Date: 2026-11-11

## Context

Phase 0 found that `fluvie_cli` 0.3.1 downloads an FFmpeg 8.1 build configured with `--enable-gpl` and `--enable-libx264`. The web encoder loads `@ffmpeg/core` 0.12.10, which the npm registry marks `GPL-2.0-or-later`. Criterion L2 accepts a downloaded binary for the headless tool only when it is a separate process and its license is LGPL or permissive. That binary fails L2. The published mobile encoder does not bundle FFmpeg. It encodes through the platform API.

## Decision

- GPL FFmpeg with libx264 is accepted only as a separate process in the developer tool: headless rendering on a developer machine or a developer server.
- The project does not bundle that binary in an app, does not put it in a published package, and does not distribute it.
- Production rendering uses the device encoder through `fluvie_mobile_encoder`, with no FFmpeg.
- Criterion L2 stays a fail for the CLI binary and for the web core. This decision does not edit L2.

## Alternatives

- Reject the GPL binary for the developer tool as well, and require an LGPL-only build or a permissive H.264 encoder before any headless render.
- Vendor or link the GPL binary into an application. Rejected: that would put GPL code in a distributed package.

## Consequences

- A developer can point the CLI at a GPL FFmpeg binary they obtain themselves. The repository does not store that binary or its output video.
- An app build and a published package stay on the platform encoder.
- Changing L2 so the GPL binary would pass is out of scope for this decision.

## Evidence

One archive from the pin table in `fluvie_cli` `lib/src/ffmpeg/ffmpeg_release.dart` was downloaded. Its size, SHA-256, and `ffmpeg -version` output are in the L2 headless result in `docs/evaluation.md` and in `docs/dependencies.md`. Checked 2026-11-11.
