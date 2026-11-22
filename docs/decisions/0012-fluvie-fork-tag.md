# 0012. Pin the desktop renderer to the Fluvie fork

Accepted 2026-11-21.

## Context

The desktop renderer uses Fluvie's public composition and capture APIs. The
maintained fork has landed fixes for stream-backed clip capture, transition
stills and audio timing alongside frame context and render metrics. Earlier
phase probes measure the published packages at 0.3.1.

## Decision

Resolve the desktop package's `fluvie` dependency from `packages/fluvie` in
the maintained fork at Git tag `v0.3.1-socialstudio.2`. The lockfile records
the tag's exact commit. Advance to a new tag and review the resolved commit
when updating the renderer. Keep the phase probe pins for reproducibility.
The desktop CLI continues to launch the installed FFmpeg locally and to
capture with the frame cache disabled.

Keeping hosted 0.3.1 would leave fixes in the fork unavailable to this
consumer. Tracking the fork's branch would make updating the lockfile depend
on the branch tip. A tag gives the dependency a named revision and lets
other checkouts resolve the same snapshot.

The fork kept the MIT license and the desktop lockfile changed only the
Fluvie entry. The existing desktop capture and export tests exercise the
integration through the locked dependency.

[Fork tag](https://github.com/moisesaguiarjunior/fluvie/tree/v0.3.1-socialstudio.2)
