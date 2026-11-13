# Desktop render cancellation verification

Scope: roadmap step 4, POSIX desktop commands. This record does not certify
mobile lifecycle handling, hardware encoding or Windows process-tree shutdown.

## Permanent controls

`test/render_cancellation_test.dart` runs the actual CLI with controlled workers
for preflight, capture, encoding and cover extraction. Each phase is interrupted
with both SIGINT and SIGTERM. The tests first observe that the worker reached
the selected phase and, after setup, that staging and frame workspaces exist.
They require the conventional cancellation exit code, the cancellation message,
no final output and removal of the CLI-owned workspaces. Worker stubs exercise
transaction/lifecycle wiring; they are not encoding conformance measurements.

Both signals are also delivered after the cover worker has completed, while
a controlled FIFO holds the review write open. This forces the CLI to process
the interrupt between worker completion and atomic publication. Removing only
the final cancellation checkpoint makes that persistent regression fail. This
is a filesystem pause in the test fixture, not a production test hook.

A further test interrupts the actual Flutter capture after its raw-frame file
appears and before it reaches the authored full frame count. It requires the
same output/workspace cleanup and checks that the workspace does not reappear.
The existing frozen-job regressions continue to render and decode real video
through the new process runner as normal-completion controls.

`test/render_processes_test.dart` covers ordinary command failure, malformed
readiness, cancellation before and during process startup, and resistant worker
families. One family retains stdout/stderr; another has a normally terminating
leader and a SIGTERM-resistant descendant with redirected pipes. The heartbeat
must be active before cancellation and stopped after return. Bounded fixtures
and failure cleanup keep test mutations from leaving permanent workers.

## Run the checks

From `flutter/social_studio`:

```sh
flutter test --no-pub test/render_processes_test.dart test/render_cancellation_test.dart test/frozen_job_test.dart
```

From the repository root:

```sh
bash tool/check.sh
```

## Boundary

The parent waits for its command and pipes plus group shutdown, then executes
existing staging cleanup. It does not provide a native process sandbox. A child
that creates another session can escape its group; SIGKILL of the CLI and power
loss cannot run Dart cleanup. Arbitrary tool behavior after normal completion
is not a general descendant-reaping guarantee. The private launcher protocol
is operational control data, not a render-job input format.

After publication has started, an interrupt does not retract a completed export.
Windows keeps the previous ordinary process path. Its cancellation and native
mobile interruption remain unverified.

## Executed results

On 2026-11-13, `bash tool/check.sh` passed on the completed increment: 55 hook
controls, three coverage-tool tests, 61 schema tests and 98 Flutter tests
(75 desktop, six phase 0, seventeen phase 1), with clean formatting/strict
analysis. The independent reviewer repeated the full check and publication
controls, reporting no blocking findings. Exact Linux golden comparisons were
explicitly skipped on this development platform; existing references were not
regenerated. Remote Linux checks are a separate validation path.

Disposable mutation controls failed at their intended assertions when they:

- removed the independent shutdown wait after leader/pipes exited;
- signalled only the leader, leaving a resistant descendant alive;
- accepted a launcher without its readiness handshake;
- disabled signal watches in the actual CLI;
- removed only the final cancellation check before publication.

These failures were not compiler/missing-tool errors. The fixtures and temporary
copies were cleaned. The first two controls protect the early-leader-exit
problem found during review; the final control protects the interval after the
last subprocess finishes. The CLI yields before its last checkpoint to process
interrupts queued during synchronous integrity checks.

`bash tool/coverage.sh` passed all 75 desktop tests and measured 344/355 library
lines (96.90%). See [coverage evidence](coverage.md) for scope and remaining paths.
The same increment adds snapshot replay/JPEG/review/input-error contracts and
normalizes malformed JSON diagnostics without exposing source excerpts.

Software: Flutter 3.47.9, Dart 3.13.7, Python 3.10.20, FFmpeg 8.1.2.
No phone, native encoder, Windows interruption or deliberately detached worker
session was certified. Existing process-ID signal semantics apply; this is not
an OS-level process sandbox or universal descendant reaper.
