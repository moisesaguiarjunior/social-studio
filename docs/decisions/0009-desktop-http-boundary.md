# 0009 — Deny new Dart HTTP connections during desktop capture

Status: implemented locally for review.
Date: 2026-11-13.

## Context

Roadmap step 2 calls for executable privacy controls and an intentional network
failure control. Local-job validation, Fluvie's empty host allowlist and FFmpeg's
file/pipe whitelist already protect the supported input path. They do not
independently catch an accidental Dart HTTP request added during capture.
Searches covered `HttpOverrides`, `networkAllowlist`, `resolverScope`,
`MediaHttpClient`, `runAsync`, `map_metadata` and the reuse map. Fluvie eagerly
creates an HTTP client even when all media are local, so rejecting construction
would break valid renders.

## Decision

Use Dart's zone-scoped `HttpOverrides` to create clients with a rejecting
`connectionFactory` and direct proxy selection. Harmless construction and close
remain available; a connection attempt throws a typed error without a URL or
content. Apply the boundary around capture. The pinned Flutter binding implements
`tester.runAsync` by forking `Zone.current` with real timers; it preserves the
HTTP override, so no second guard is needed in that callback. Keep the existing validation, allowlist and
encoder controls. No dependency or global override is introduced.

This is a guard for new Dart HTTP clients created within that zone. It cannot
intercept clients created beforehand, deliberate client reconfiguration, raw
sockets, native code or subprocess networking. It is not an OS sandbox or
complete step 2 acceptance. No mobile adoption follows from this change.

## Alternatives and consequences

Relying only on the media allowlist would miss HTTP calls outside media loading.
Rejecting client construction breaks Fluvie's local resolver. A global override
would affect unrelated work and require restoration across concurrent jobs.
An OS-level sandbox is a separate deployment-specific boundary and remains open.
The small zone guard reuses the SDK's socket-creation seam without replacing
Fluvie's resolver or network client implementation.

## Evidence

The loopback regression proves an endpoint works before the guarded attempt,
then checks the typed rejection, no additional server request and zone restoration.
The existing real CLI render is the valid capture control. Synthetic source
metadata regression and disposable mutation/injection evidence are recorded in
[desktop verification](../verification/desktop-story.md).

SDK references checked 2026-11-13:
[HttpOverrides.runZoned](https://api.dart.dev/dart-io/HttpOverrides/runZoned.html)
and [HttpClient.connectionFactory](https://api.dart.dev/dart-io/HttpClient/connectionFactory.html).
