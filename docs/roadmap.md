# Execution roadmap

Working plan, 2026-11-12. The desktop JSON-to-Story workflow is usable. Mobile
capture without a test binding and phone acceptance remain separate milestones.
This plan does not adopt Fluvie unconditionally or expand the phase 1 platform
scope.

## Reuse

Reuse the phase 1 scene, supplied transcript, asset generators, container
inspector, Flutter golden matcher, current check entry point and Fluvie's
capture/resolver interfaces. Searches covered `matchesGoldenFile`,
`first_yavg_ms`, `audio_frame_ms`, `preResolveCaptions`, `CaptureHost`,
`render_aspect.dart`, and `OffscreenCaptureHost` in the repository and the
installed 0.3.1 dependency sources. Do not create a second video engine,
image comparator, platform-requirements table or package checker.

## Ordered implementation

| Step | Dependencies | Deliverable | Acceptance |
| --- | --- | --- | --- |
| 0. Protect current evidence | Current validation work | PTS-based flash measurement, measured frame spacing and existing PNG comparisons | Original timing tests fail before the fix; valid clips pass after it; changed scene fails the golden comparison; reference PNGs unchanged; full repository checks pass |
| 1. Resolve mobile capture gaps | Independent upstream review | Minimal upstream-ready reproductions and a local patch to the canonical caption preparation and motion/capture lifecycle | First reproduce missing caption preparation and invisible animated media on 0.3.1; corrected capture works without `LiveTestWidgetsFlutterBinding`, forced application-wide draw calls or wall-clock-driven animation; repeated renders and cleanup pass on desktop; independent review before any publication |
| 2. Make privacy executable | Stable capture path and privacy review | Offline input boundary and output metadata checks, including failure controls | Local assets work; remote image/video/audio/font/transcript inputs and redirect attempts fail before access; an intentional network attempt is detected; synthetic location/device tags are absent from decoded output metadata; document native paths not yet observed |
| 3. Define the smallest spec | Stable job contract | Versioned JSON Schemas and valid/invalid synthetic jobs for one Story | Schema owns platform data, asset references, caption timing and template slots; Dart validates/implements it without a duplicate model of policy; every rejection has a valid control; profile numbers trace to official sources and check dates |
| 4. Deliver one finished piece | Step 3 and template design | One synthetic template rendered headlessly, cover and captions, plus a runnable app example using the same job | Review every reference frame; check decoded video, text, audio offset and complete duration; no test-only render adapter; cancellation, cleanup, invalid input and repeated-job isolation tested; no device performance claim |
| 5. Device acceptance | Qualifying phones; steps 1–4 | Android/iOS encode, actual share handoff, quality and performance record | Execute the existing evaluation criteria; report memory, elapsed time, lifecycle interruptions, A/V offset and headless/device differences; verify sharing on the actual target app; keep failed/unavailable criteria explicit |
| 6. Expand core v0 | Step 5 | Additional profiles and templates using the same schemas | Each profile has sourced requirements and conformance jobs; add React only after demand and a stable cross-renderer contract |

Steps 1–4 can advance without a phone. Native codec behavior, thermal behavior,
device resource limits, actual sharing and headless/device equivalence cannot
be certified by desktop tests or an emulator. A successful step 4 is a
desktop-verified prototype, not release approval for the mobile default.

For step 1, start at `fluvie/lib/src/rendering/render_aspect.dart` and
`fluvie_mobile_encoder/lib/src/offscreen_capture_host.dart` in version 0.3.1.
The aspect pre-pass resolves media/clips but not captions; the offscreen host
flushes layout/paint but not the post-frame callback used to resolve motion.
The current integration test compensates for both. Reuse the upstream
caption collector and animation lifecycle rather than copying their logic.
Do not edit the global package cache. Prepare an isolated upstream checkout
and validate the patch there; a version change or temporary dependency override
must be explicit, locked and reviewed. Remove the test workaround only after
the replacement passes an ordinary-binding capture test. Hardware encode
acceptance stays in step 5.

## Step 1 progress — local draft patches

The pinned 0.3.1 capture failures now have desktop engine reproductions and
local patch candidates in `probes/phase1/upstream/`. The baseline fails motion,
caption and disposal controls; the patched copy passes using an ordinary
binding with application frames disabled. No dependency override was adopted.
Independent review identified remaining web caption and host resource-disposal
gaps. Full Story integration, application-build re-entry and upstream-suite
validation remain before step 1 is complete.

## Product increment — desktop Story jobs

The maintainer prioritized a usable implementation after validation work.
`flutter/social_studio` now provides a checkout-based JSON-to-Story command,
backed by canonical `spec/desktop-story` schemas/profile/template. It generates MP4 video,
a cover, SRT captions, a portable review page and an output manifest using the existing headless renderer. This
advances the desktop portions of steps 3–4 without adopting the mobile patches.
Remote media are rejected. Desktop privacy checks are recorded under step 2;
native execution remains open. The template accepts one photo or an ordered photo sequence, supplied timed
text and a local WAVE track. Per-scene durations produce hard cuts while audio,
captions and cover retain the global timeline. General template authoring,
transition effects and sharing are not implemented.

The capture draft now also checks interleaved application frames and cleanup
following a deliberately failed capture. These are controlled desktop engine
checks; native event delivery, interruptions and hardware encoding remain open.

## Step 2 progress — desktop privacy checks

Desktop jobs reject remote image, video, audio, font and transcript references,
including redirect URLs, before a file or a socket is opened. The existing
Fluvie resolver, configured with an empty network allowlist, reports an
intentional network fetch before any request. Encoded output is checked with
synthetic location and device tags: those tags remain visible when metadata
copying is left on, and they are absent when the desktop encode disables that
copying.

`docs/verification/privacy.md` lists the native paths these desktop checks do
not observe. The phase 0 network row is unchanged. This is not phone acceptance.
