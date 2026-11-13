import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A handled desktop interrupt. No completed output has been published yet.
final class RenderCancelledException implements Exception {
  /// Retains the first interrupt for the conventional shell exit status.
  const RenderCancelledException(this.signal);

  /// SIGINT or SIGTERM that requested cancellation.
  final ProcessSignal signal;

  /// Shell convention: 130 for SIGINT, 143 for SIGTERM.
  int get exitCode => 128 + signal.signalNumber;

  @override
  String toString() => 'Render cancelled.';
}

/// Sequential desktop commands with owned POSIX process groups and cancellation.
///
/// The local Python launcher creates a session before reporting readiness.
/// Cancellation terminates that group, escalates after two seconds and awaits
/// process exit and pipe closure before returning. Group shutdown is awaited
/// independently when the leader and its pipes exit early. Windows retains ordinary
/// process execution; handled cancellation is not supported there.
final class RenderProcesses {
  /// Creates a runner using [launcherPath], optionally installing signal watches.
  ///
  /// [watchSignals] is false for callers that request cancellation themselves.
  RenderProcesses({required this.launcherPath, bool watchSignals = true}) {
    if (watchSignals && !Platform.isWindows) {
      for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
        _subscriptions.add(signal.watch().listen(cancel));
      }
    }
  }

  /// Local `tool/run_process.py` from this checkout; requires Python 3 on POSIX.
  final String launcherPath;
  final _subscriptions = <StreamSubscription<ProcessSignal>>[];
  Process? _active;
  ProcessSignal? _cancelled;
  Timer? _escalation;
  Completer<void>? _shutdown;
  bool _ready = false;
  bool _running = false;
  bool _disposed = false;

  /// Requests cancellation, retaining the first signal's exit code.
  ///
  /// Repeated requests do not restart the grace period. Throws
  /// [UnsupportedError] on Windows or [ArgumentError] for another signal.
  void cancel(ProcessSignal signal) {
    if (Platform.isWindows) throw UnsupportedError('POSIX cancellation only.');
    if (signal != ProcessSignal.sigint && signal != ProcessSignal.sigterm) {
      throw ArgumentError.value(signal, 'signal', 'Use SIGINT or SIGTERM.');
    }
    _cancelled ??= signal;
    _stopActive();
  }

  /// Throws [RenderCancelledException] if cancellation has been requested.
  ///
  /// Check immediately before starting publication. Once the atomic rename
  /// begins, a completed export is retained even if an interrupt arrives then.
  void throwIfCancelled() {
    final signal = _cancelled;
    if (signal != null) throw RenderCancelledException(signal);
  }

  /// Executes one command, capturing output for errors like `Process.run`.
  ///
  /// Throws [ProcessException] for failure or [RenderCancelledException] after
  /// interrupted workers stop. Concurrent commands and use after disposal are
  /// programmer errors. The runner does not read or copy render media.
  Future<void> run(
    String command,
    List<String> arguments, {
    String? cwd,
    Map<String, String>? environment,
  }) async {
    if (_disposed || _running) {
      throw StateError(
        'Render processes must run sequentially before disposal.',
      );
    }
    _running = true;
    try {
      await _run(command, arguments, cwd: cwd, environment: environment);
    } finally {
      _running = false;
    }
  }

  Future<void> _run(
    String command,
    List<String> arguments, {
    String? cwd,
    Map<String, String>? environment,
  }) async {
    throwIfCancelled();
    if (Platform.isWindows) {
      final result = await Process.run(
        command,
        arguments,
        workingDirectory: cwd,
        environment: environment,
      );
      _checkResult(
        command,
        arguments,
        result.exitCode,
        '${result.stderr}\n${result.stdout}',
      );
      return;
    }
    final process = await Process.start(
      'python3',
      [launcherPath, command, ...arguments],
      workingDirectory: cwd,
      environment: environment,
    );
    _active = process;
    final output = StringBuffer();
    final errors = StringBuffer();
    Future<void> readOutput() async {
      var first = true;
      await for (final line
          in process.stdout
              .transform(const Utf8Decoder(allowMalformed: true))
              .transform(const LineSplitter())) {
        if (first && line == 'social-studio-process-ready-v1') {
          _ready = true;
          if (_cancelled != null) _stopActive();
        } else {
          output.writeln(line);
        }
        first = false;
      }
    }

    try {
      final result = await Future.wait<Object?>([
        process.exitCode,
        readOutput(),
        process.stderr
            .transform(const Utf8Decoder(allowMalformed: true))
            .forEach(errors.write),
        process.stdin.close(),
      ]);
      // A descendant may redirect its pipes and outlive a terminating leader.
      if (_cancelled != null) await _shutdown?.future;
      throwIfCancelled();
      final code = result.first;
      if (code is! int) throw StateError('Missing render process exit status.');
      _checkResult(command, arguments, code, '$errors\n$output');
      if (!_ready) {
        throw StateError('Render process launcher did not report readiness.');
      }
    } finally {
      _escalation?.cancel();
      _escalation = null;
      _shutdown = null;
      _active = null;
      _ready = false;
    }
  }

  void _stopActive() {
    final process = _active;
    if (process == null || !_ready) return;
    final shutdown = _shutdown ??= Completer<void>();
    Process.killPid(-process.pid, ProcessSignal.sigterm);
    _escalation ??= Timer(const Duration(seconds: 2), () {
      Process.killPid(-process.pid, ProcessSignal.sigkill);
      if (!shutdown.isCompleted) shutdown.complete();
    });
  }

  /// Releases signal watches after all commands have completed.
  Future<void> dispose() async {
    if (_running) {
      throw StateError('Await active commands before disposal.');
    }
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }
}

void _checkResult(
  String command,
  List<String> arguments,
  int code,
  String output,
) {
  if (code != 0) throw ProcessException(command, arguments, output, code);
}
