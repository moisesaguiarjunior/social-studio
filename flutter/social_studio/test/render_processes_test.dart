import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:social_studio/src/render_processes.dart';

void main() {
  late Directory temp;
  late RenderProcesses runner;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('render-process-test-');
    runner = RenderProcesses(
      launcherPath: p.absolute('tool/run_process.py'),
      watchSignals: false,
    );
  });
  tearDown(() async {
    await runner.dispose();
    temp.deleteSync(recursive: true);
  });

  test('ordinary commands preserve stdout, stderr and failure exit status', () async {
    await runner.run('python3', ['-c', 'print("valid command")']);
    await expectLater(
      runner.run('python3', [
        '-c',
        'import sys; print("synthetic failure", file=sys.stderr); sys.exit(17)',
      ]),
      throwsA(
        isA<ProcessException>()
            .having((error) => error.errorCode, 'exit status', 17)
            .having(
              (error) => error.message,
              'stderr',
              contains('synthetic failure'),
            ),
      ),
    );
  });

  test('real signal subscriptions cancel work and redact worker output', () async {
    // Keep the test VM safe even if the runner's handler regresses. The
    // independent listener is a valid control that delivery actually occurred.
    final delivered = Completer<void>();
    final safety = ProcessSignal.sigint.watch().listen((_) {
      if (!delivered.isCompleted) delivered.complete();
    });
    addTearDown(safety.cancel);
    await runner.dispose();
    runner = RenderProcesses(launcherPath: p.absolute('tool/run_process.py'));
    await expectLater(
      runner.run('python3', [
        '-c',
        'import os,signal,time; print("synthetic private worker output", flush=True); os.kill(os.getppid(), signal.SIGINT); time.sleep(3)',
      ]),
      throwsA(
        isA<RenderCancelledException>()
            .having((error) => error.exitCode, 'interrupt', 130)
            .having(
              (error) => error.toString(),
              'safe diagnostic',
              isNot(contains('synthetic private worker output')),
            ),
      ),
    );
    await delivered.future;
  }, skip: Platform.isWindows);

  test('a launcher without a readiness handshake is rejected', () async {
    await runner.dispose();
    final launcher = File(p.join(temp.path, 'invalid-launcher.py'))
      ..writeAsStringSync('print("not a supervisor")');
    runner = RenderProcesses(launcherPath: launcher.path, watchSignals: false);
    await expectLater(
      runner.run('python3', ['-c', 'pass']),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'protocol',
          contains('readiness'),
        ),
      ),
    );
  }, skip: Platform.isWindows);

  test('cancellation before startup prevents execution', () async {
    runner.cancel(ProcessSignal.sigint);
    final marker = p.join(temp.path, 'should-not-exist');
    await expectLater(
      runner.run('python3', [
        '-c',
        'from pathlib import Path; import sys; Path(sys.argv[1]).touch()',
        marker,
      ]),
      throwsA(
        isA<RenderCancelledException>().having(
          (error) => error.exitCode,
          'interrupt status',
          130,
        ),
      ),
    );
    expect(File(marker).existsSync(), isFalse);
  }, skip: Platform.isWindows);

  test(
    'startup cancellation waits for group readiness before signalling',
    () async {
      final marker = File(p.join(temp.path, 'late-work'));
      final running = runner.run('python3', [
        '-c',
        'import sys,time; from pathlib import Path; time.sleep(3); Path(sys.argv[1]).touch()',
        marker.path,
      ]);
      runner.cancel(ProcessSignal.sigint);
      await expectLater(running, throwsA(isA<RenderCancelledException>()));
      expect(
        marker.existsSync(),
        isFalse,
        reason: 'Cancellation during Process.start must stop the new group.',
      );
    },
    skip: Platform.isWindows,
  );

  for (final detachedPipes in [false, true]) {
    test(
      detachedPipes
          ? 'leader exit and closed pipes do not skip descendant shutdown'
          : 'cancellation stops a resistant worker and its descendant before returning',
      () async {
        final heartbeat = File(p.join(temp.path, 'heartbeat'));
        final worker = File(p.join(temp.path, 'worker.py'))
          ..writeAsStringSync('''import signal, subprocess, sys, time
${detachedPipes ? '' : 'signal.signal(signal.SIGTERM, signal.SIG_IGN)'}
child = subprocess.Popen([sys.executable, '-c', "import signal,sys,time; from pathlib import Path; signal.signal(signal.SIGTERM, signal.SIG_IGN); p=Path(sys.argv[1]); n=0; end=time.monotonic()+5\\nwhile time.monotonic()<end:\\n n+=1; p.write_text(str(n)); time.sleep(0.02)", sys.argv[1]], ${detachedPipes ? 'stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL' : ''})
time.sleep(5)
''');
        final running = runner.run('python3', [worker.path, heartbeat.path]);
        // Attach an error listener before cancellation can complete the future.
        final rejected = expectLater(
          running,
          throwsA(
            isA<RenderCancelledException>().having(
              (error) => error.exitCode,
              'termination status',
              143,
            ),
          ),
        );
        try {
          final deadline = DateTime.now().add(const Duration(seconds: 10));
          while (!heartbeat.existsSync()) {
            if (DateTime.now().isAfter(deadline)) {
              fail('Descendant did not start.');
            }
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
          final before = heartbeat.readAsStringSync();
          await Future<void>.delayed(const Duration(milliseconds: 150));
          expect(
            heartbeat.readAsStringSync(),
            isNot(before),
            reason: 'The descendant is genuinely active before cancellation.',
          );
          final stopping = Stopwatch()..start();
          runner.cancel(ProcessSignal.sigterm);
          await rejected;
          expect(stopping.elapsed, lessThan(const Duration(seconds: 4)));
          final stopped = heartbeat.readAsStringSync();
          await Future<void>.delayed(const Duration(milliseconds: 150));
          expect(
            heartbeat.readAsStringSync(),
            stopped,
            reason:
                'No descendant continues writing after cancellation returns.',
          );
        } finally {
          runner.cancel(ProcessSignal.sigterm);
          await rejected;
        }
      },
      skip: Platform.isWindows,
      timeout: const Timeout(Duration(seconds: 20)),
    );
  }
}
