# 0010 — Handled cancellation for desktop render processes

Status: implemented locally for review.
Date: 2026-11-13.

## Context

Roadmap step 4 requires cancellation and cleanup. The CLI's `Process.run` calls
wait for individual commands, but a default interrupt can terminate the CLI
without stopping capture/encoder descendants or running its staging cleanup.
Searches covered `cancel`, `ProcessSignal`, `Process.start`, signal handling,
Fluvie capture callers and the reuse map. No existing repository component owns
this lifecycle. Fluvie still owns capture; the CLI owns its subprocess lifetime.

## Decision

Use one sequential `RenderProcesses` instance for preflight, capture, encode
and cover commands. On POSIX, the already required local Python 3 runtime calls
`os.setsid()` and reports readiness before executing each command. This gives
each command an isolated process group. A cancellation arriving during startup
is latched until that readiness handshake, so no group is signalled too early.
No shell interpolation, binary download or Python package is introduced.

The CLI watches SIGINT/SIGTERM while rendering. The first request sends SIGTERM
to the current group; after a two-second grace period it sends SIGKILL. Repeated
requests do not restart that grace period. Group shutdown completes independently of leader
exit or pipe closure: a descendant can redirect its output and outlive its
leader. The runner waits for the shutdown interval, process exit and drained
pipes before returning cancellation. This is not a claim to reap every orphaned
OS process. The CLI then removes its staging and frame/snapshot workspace,
returning shell status 130 or 143 according to the first interrupt.

Worker temporary-directory variables point into the frame workspace. Existing
capture, mux, media-integrity and atomic rename logic remain authoritative.
Cancellation is checked before publication. Once the final atomic rename begins,
a completed export is retained; cancellation is not a request to delete it.
Windows keeps ordinary process execution; handled tree cancellation there is
unimplemented. SIGKILL, power loss, deliberately detached worker groups and
native/mobile interruption are outside this boundary.

## Alternatives and consequences

Killing only the direct child leaves capture/encoder descendants running.
Creating a detached Dart process loses the exit status needed by the existing
CLI. Shell-specific `setsid` utilities are not available on all desktop targets.
A small local Python launcher supplies the POSIX group boundary without native
FFI bindings or another process-manager dependency. OS-specific process handles
and subreapers would require separate implementations and acceptance criteria.

Python is now required for POSIX rendering itself, not only fixture generation.
Its external-runtime license is recorded in the dependency inventory. This does
not change the unpublished job schema or adopt mobile capture patches.

## Evidence

[Cancellation verification](../verification/cancellation.md) covers both signals
at each CLI process phase, startup races, resistant descendants with inherited
and redirected pipes, real Flutter capture interruption and successful renders.
The redirected-pipe case was added after independent review reproduced an early
shutdown return. Negative controls challenge signal wiring and group cleanup.

SDK references checked 2026-11-13:
[ProcessSignal.watch](https://api.dart.dev/dart-io/ProcessSignal/watch.html) and
[Python os.setsid](https://docs.python.org/3/library/os.html#os.setsid).
