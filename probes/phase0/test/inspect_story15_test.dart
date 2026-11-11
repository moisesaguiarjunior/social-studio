import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Runs the story inspector against a synthetic box file.
///
/// The file is not a playable video. The controls only check how the
/// inspector reports a probe that fails and a probe that is not installed.
Future<ProcessResult> _inspect({
  required String python,
  required File sample,
  required Map<String, String> environment,
}) {
  return Process.run(python, [
    'tool/inspect_story15.py',
    sample.path,
  ], environment: environment);
}

void main() {
  late String python;
  late Directory directory;
  late File sample;

  setUpAll(() async {
    final resolved = await Process.run('python3', [
      '-c',
      'import sys; print(sys.executable)',
    ]);
    python = (resolved.stdout as String).trim();
    if (resolved.exitCode != 0 || python.isEmpty) {
      fail('python3 is required for the inspector controls.');
    }
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('phase0-inspect-');
    sample = File('${directory.path}/sample.bin');
    await sample.writeAsBytes([
      0,
      0,
      0,
      8,
      0x6d,
      0x6f,
      0x6f,
      0x76,
      0,
      0,
      0,
      8,
      0x6d,
      0x64,
      0x61,
      0x74,
    ]);
  });

  tearDown(() async {
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  });

  test('a failing ffprobe exits nonzero', () async {
    final probe = File('${directory.path}/failing-probe');
    await probe.writeAsString('#!/bin/sh\nexit 7\n');
    if (!probe.existsSync()) {
      fail('Could not write the failing probe.');
    }
    await Process.run('chmod', ['+x', probe.path]);

    final result = await _inspect(
      python: python,
      sample: sample,
      environment: {...Platform.environment, 'FFPROBE': probe.path},
    );

    expect(result.exitCode, 7);
    expect(result.stderr, contains('ffprobe failed with exit status 7'));
    expect(result.stdout, contains('moov_before_mdat true'));
  });

  test('a missing ffprobe stays a partial inspection', () async {
    final result = await _inspect(
      python: python,
      sample: sample,
      environment: {'PATH': directory.path},
    );

    expect(result.exitCode, 0);
    expect(result.stdout, contains('ffprobe unavailable'));
    expect(result.stdout, contains('size_bytes 16'));
  });
}
