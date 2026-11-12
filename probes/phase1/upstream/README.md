# Draft upstream capture patches

**Superseded lifecycle draft.** These files preserve the original desktop
reproduction; they are not the current integration candidate. A subsequent
independently checked correction set supersedes `capture-lifecycle.patch` and
adds `captions-sandbox.patch`: it also disposes the view/pipeline and explicitly
rejects capture during an application build. That set is not included or adopted
here. Do not apply the old and replacement lifecycle patches together. The
checker below intentionally tests the historical draft only; a green result
does not validate the replacement or authorize a dependency override. Keep the
Story workaround until the selected revision passes integration review.

These patches target the published `fluvie` and `fluvie_mobile_encoder` 0.3.1
sources. They are local contribution candidates, not an adopted dependency
override or a claim that current upstream still needs them. Research against
current upstream is a separate roadmap task.

Run from the repository root after package resolution:

```sh
python3 probes/phase1/tool/check_upstream_capture.py
```

The regular phase 1 test suite invokes this command too. It copies the pinned
packages and probe into a temporary directory, detaches the published workspace
members, and resolves path overrides offline. It first requires three specific
baseline assertion failures, applies the patches with `git apply --check`, then
requires successful capture. The source cache, root lockfiles and normal
integration test remain unchanged. Temporary copies are deleted on exit.

## Reproductions and changes

- `captions.patch` reuses `compositionVideo` and `collectCaptionSource` in the
  aspect pre-pass, including the `Directionality` wrapper used by mobile.
  Captions resolve before any frame is mounted, using the existing resolver.
- `capture-lifecycle.patch` introduces a host-scoped preparation callback.
  `VideoState` uses it when present and retains the normal post-frame fallback
  for preview/headless callers. The production offscreen host drains only its
  own callbacks after building the complete tree and rebuilds before capture.
  It does not call application frame handlers or use elapsed time for motion.
  Disposal now unmounts its child tree and clears pending preparation.

`capture_contract_test.dart` runs in the Flutter engine with an ordinary
`WidgetsFlutterBinding` subclass that disables automatic application frames.
It is not `TestWidgetsFlutterBinding` or `LiveTestWidgetsFlutterBinding`.
It captures pixels through the real production `OffscreenCaptureHost` and
aspect renderer. The controls require visible moving content, byte-identical
repeated captures, caption ink without caller pre-resolution, no execution of
an application post-frame callback, and an unmounted child after disposal.
The tiny canvas and square aspect are synthetic diagnostic choices, not a
platform profile or a conformance claim for the complete Story.

The unpatched baseline produces zero gold pixels, zero caption ink and retains
the mounted child after disposal. The patched version passes all three tests.
A missing tool or compilation failure does not satisfy the baseline controls.

## Limits and adoption

No hardware encoder or actual app sharing runs here. This prepares Fluvie's
timeline; arbitrary Flutter/Lottie tickers are not driven by the new callback.
Application-frame concurrency, interruption, nested composition behavior and
the full upstream suite still need upstream review. The test suppresses engine
frames to prove isolation; it is not a full foreground-UI concurrency test.
The patch is deliberately not wired into the current Story integration test:
remove its workaround only after adopting a reviewed dependency revision and
verifying the complete Story through that revision. See `docs/roadmap.md`.

The patch context comes from the MIT-licensed packages already inventoried in
`docs/dependencies.md`; no new binary or dependency is introduced.

## Local verification record

On 2026-11-12, `bash tool/check.sh` passed: 42 hook scenarios, six phase 0
and seventeen phase 1 tests, including the disposable upstream patch check.
Formatting and strict analysis were clean. In a separate disposable override,
all six existing phase 0 tests passed against patched Fluvie, including the
unchanged frame references and deterministic buffer hash.

Software: Flutter 3.47.9, Dart 3.13.7, Python 3.10.20; FFmpeg 8.1.2 was used by
the ordinary inspector tests, not by this offscreen raw-frame reproduction.
Independent Codex review inspected the canonical callers, reran the disposable
checker and reported **no blocking findings for unadopted draft artifacts**.
The adoption limitations above remain. This is uncommitted local evidence,
not an exact-commit attestation or a claim that upstream's full suite passed.

## Additional lifecycle controls

The reproducer now interleaves explicit application-frame updates during two
captures and verifies that the app counter survives, callbacks run, and output
frames remain identical. A second control injects a capture error after the
first frame, verifies that the boundary is unmounted, and starts another job.
Automatic frame scheduling is still disabled: these controlled interleavings
are not a native scheduler/concurrency certification. The source patches are
unchanged; only their acceptance coverage expanded.

## External review follow-up

The independent report supplied on 2026-11-12 concludes **changes required
before adoption**. It reports a passing desktop checker for the three original
defects, but identifies the unpatched `renderToSandbox` caption caller and
missing `RenderView`/`PipelineOwner` disposal. Resource accumulation is a
hypothesis in that report, not a measured leak. Capture re-entry during an
application build, file-backed captions and nested compositions remain open.
The scoped draft verdict above does not authorize a dependency override.
