import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/desktop_checkout.dart';

void main() {
  for (final phase in [
    'version',
    'capture',
    'encode',
    'cover',
    'publication',
  ]) {
    for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
      test(
        '${signal.name} during $phase cleans the actual CLI transaction',
        () async {
          final temp = Directory.systemTemp.createTempSync('cancel-story-');
          addTearDown(() => temp.deleteSync(recursive: true));
          final (:package, :job, :temporary, :output) = _fixture(temp);
          if (phase == 'publication') {
            final review = File(p.join(package.path, 'assets/review.html'));
            review.writeAsStringSync(
              '${review.readAsStringSync()}<!--${List.filled(1024 * 1024, 'x').join()}-->',
            );
          }
          final tools = Directory(p.join(temp.path, 'tools'))..createSync();
          final program = '''#!/usr/bin/env python3
import json, os, subprocess, sys, time
from pathlib import Path
if Path(sys.argv[0]).name == 'flutter':
    phase = 'capture'
    target = Path(os.environ['SOCIAL_STUDIO_FRAMES']) / 'frames.rgba'
elif sys.argv[1:] == ['-version']:
    phase = 'version'
    target = None
else:
    target = Path(sys.argv[-1])
    phase = 'cover' if target.name == 'cover.png' else 'encode'
if phase == 'cover' and os.environ['TEST_CANCEL_PHASE'] == 'publication':
    target.write_bytes(b'synthetic cover')
    fifo = target.with_name('review.html')
    os.mkfifo(fifo)
    subprocess.Popen([sys.executable, os.environ['TEST_PAUSE_PUBLICATION'], str(fifo), str(os.getppid())], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    sys.exit(0)
if phase == os.environ['TEST_CANCEL_PHASE']:
    marker = Path(os.environ['TEST_READY'])
    pending = marker.with_suffix('.pending')
    pending.write_text(json.dumps({'group': os.getpgrp(), 'phase': phase}))
    pending.replace(marker)
    time.sleep(10)
    sys.exit(19)
if target is not None:
    if phase == 'capture':
        with target.open('wb') as output:
            output.truncate(96 * 160 * 4 * 24)
    else:
        target.write_bytes(b'synthetic stage output')
''';
          for (final name in ['flutter', 'encoder']) {
            final script = File(p.join(tools.path, name))
              ..writeAsStringSync(program);
            expect(
              (await Process.run('chmod', ['+x', script.path])).exitCode,
              0,
            );
          }
          final ready = File(p.join(temp.path, 'ready.json'));
          final process = await Process.start(
            'dart',
            ['run', 'bin/social_studio.dart', 'render', job.path, output],
            workingDirectory: package.path,
            environment: {
              'PATH':
                  '${tools.path}${Platform.isWindows ? ';' : ':'}${Platform.environment['PATH']}',
              'FLUVIE_FFMPEG': p.join(tools.path, 'encoder'),
              'TEST_CANCEL_PHASE': phase,
              'TEST_READY': ready.path,
              'TEST_PAUSE_PUBLICATION': p.absolute(
                'test/support/pause_publication.py',
              ),
              'TEST_INTERRUPT': '${signal.signalNumber}',
              'TMPDIR': temporary.path,
            },
          );
          final stdout = process.stdout.transform(utf8.decoder).join();
          final stderr = process.stderr.transform(utf8.decoder).join();
          var verified = false;
          try {
            final deadline = DateTime.now().add(const Duration(seconds: 15));
            while (!ready.existsSync()) {
              if (DateTime.now().isAfter(deadline)) {
                fail('Worker did not reach $phase.');
              }
              await Future<void>.delayed(const Duration(milliseconds: 20));
            }
            if (phase != 'version') {
              expect(_staging(temp), hasLength(1));
              expect(_frames(temporary), hasLength(1));
            }
            if (phase != 'publication') {
              expect(process.kill(signal), isTrue);
            }
            expect(
              await process.exitCode,
              128 + signal.signalNumber,
              reason: '${await stderr}\n${await stdout}',
            );
            expect(await stderr, contains('Render cancelled.'));
            expect(Directory(output).existsSync(), isFalse);
            expect(_staging(temp), isEmpty);
            expect(_frames(temporary), isEmpty);
            verified = true;
          } finally {
            if (!verified && ready.existsSync()) {
              final Object? marker = jsonDecode(ready.readAsStringSync());
              if (marker is Map<String, Object?>) {
                final pid = marker['group'];
                if (pid is int) Process.killPid(-pid, ProcessSignal.sigkill);
              }
            }
            if (!verified) process.kill(ProcessSignal.sigkill);
            await process.exitCode;
            await stdout;
            await stderr;
          }
        },
        skip: Platform.isWindows,
        timeout: const Timeout(Duration(seconds: 30)),
      );
    }
  }
  test(
    'SIGINT stops the real Flutter capture before publication',
    () async {
      final temp = Directory.systemTemp.createTempSync('cancel-real-capture-');
      addTearDown(() => temp.deleteSync(recursive: true));
      final (:package, :job, :temporary, :output) = _fixture(
        temp,
        realCapture: true,
      );
      final process = await Process.start(
        'dart',
        ['run', 'bin/social_studio.dart', 'render', job.path, output],
        workingDirectory: package.path,
        environment: {'TMPDIR': temporary.path},
      );
      final stdout = process.stdout.transform(utf8.decoder).join();
      final stderr = process.stderr.transform(utf8.decoder).join();
      var verified = false;
      try {
        final deadline = DateTime.now().add(const Duration(seconds: 30));
        File? raw;
        while (raw == null) {
          for (final frames in _frames(temporary)) {
            final candidate = File(p.join(frames.path, 'frames.rgba'));
            if (candidate.existsSync()) raw = candidate;
          }
          if (DateTime.now().isAfter(deadline)) {
            fail('Real capture did not start.');
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(
          raw.lengthSync(),
          lessThan(320 * 568 * 4 * 360),
          reason: 'Interrupt while the actual capture is still incomplete.',
        );
        process.kill(ProcessSignal.sigint);
        expect(
          await process.exitCode,
          130,
          reason: '${await stderr}\n${await stdout}',
        );
        expect(await stderr, contains('Render cancelled.'));
        expect(Directory(output).existsSync(), isFalse);
        expect(_staging(temp), isEmpty);
        expect(_frames(temporary), isEmpty);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(
          _frames(temporary),
          isEmpty,
          reason: 'Stopped capture cannot recreate its workspace.',
        );
        verified = true;
      } finally {
        if (!verified) process.kill(ProcessSignal.sigkill);
        await process.exitCode;
        await stdout;
        await stderr;
      }
    },
    skip: Platform.isWindows,
    timeout: const Timeout(Duration(seconds: 45)),
  );
}

List<FileSystemEntity> _staging(Directory root) => root
    .listSync()
    .where((entry) => p.basename(entry.path).startsWith('.social-studio-'))
    .toList();
List<FileSystemEntity> _frames(Directory root) => root
    .listSync()
    .where(
      (entry) => p.basename(entry.path).startsWith('social-studio-frames-'),
    )
    .toList();

({Directory package, File job, Directory temporary, String output}) _fixture(
  Directory temp, {
  bool realCapture = false,
}) {
  final package = createDesktopCheckout(temp);
  final profile = File(
    p.join(temp.path, 'spec/desktop-story/story-profile.json'),
  );
  final Object? decoded = jsonDecode(profile.readAsStringSync());
  if (decoded is! Map<String, Object?>) throw StateError('Expected profile');
  profile.writeAsStringSync(
    jsonEncode({
      ...decoded,
      'width': realCapture ? 320 : 96,
      'height': realCapture ? 568 : 160,
      'fps': realCapture ? 30 : 2,
    }),
  );
  File('test/fixtures/tagged_red.png').copySync(p.join(temp.path, 'photo.png'));
  final audio = Process.runSync(
    Platform.environment['FLUVIE_FFMPEG'] ?? 'ffmpeg',
    [
      '-v',
      'error',
      '-f',
      'lavfi',
      '-i',
      'anullsrc=r=8000:cl=mono',
      '-t',
      '1',
      p.join(temp.path, 'audio.wav'),
    ],
  );
  expect(audio.exitCode, 0, reason: '${audio.stderr}');
  final job = File(p.join(temp.path, 'job.json'))
    ..writeAsStringSync(
      jsonEncode({
        'version': 1,
        'template': 'story-photo-v1',
        'image': 'photo.png',
        'audio': 'audio.wav',
        'durationMs': 12000,
        'coverMs': 3000,
        'captions': [
          {'startMs': 1000, 'endMs': 5000, 'text': 'Synthetic caption'},
        ],
      }),
    );
  final temporary = Directory(p.join(temp.path, 'temporary'))..createSync();
  return (
    package: package,
    job: job,
    temporary: temporary,
    output: p.join(temp.path, 'export'),
  );
}
