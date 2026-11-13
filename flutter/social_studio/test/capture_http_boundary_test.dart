import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'production capture blocks HTTP inside real asynchronous work',
    () async {
      final temp = Directory.systemTemp.createTempSync('capture-http-test-');
      addTearDown(() => temp.deleteSync(recursive: true));
      final spec = Directory(p.join(temp.path, 'spec'))..createSync();
      for (final file in Directory('../../spec/desktop-story').listSync()) {
        if (file is File) {
          file.copySync(p.join(spec.path, p.basename(file.path)));
        }
      }
      final profile = File(p.join(spec.path, 'story-profile.json'));
      final Object? decoded = jsonDecode(profile.readAsStringSync());
      if (decoded is! Map<String, Object?>) {
        throw StateError('Expected profile');
      }
      // Small synthetic canvas and cadence keep this a capture-wiring test.
      profile.writeAsStringSync(
        jsonEncode({...decoded, 'width': 96, 'height': 160, 'fps': 2}),
      );
      File('test/fixtures/tagged_red.png')
          .copySync(p.join(temp.path, 'photo.png'));
      File(p.join(temp.path, 'audio.wav')).writeAsBytesSync([
        ...ascii.encode('RIFF'),
        4,
        0,
        0,
        0,
        ...ascii.encode('WAVE'),
      ]);
      final job = File(p.join(temp.path, 'job.json'))
        ..writeAsStringSync(
          jsonEncode({
            'version': 1,
            'template': 'story-photo-v1',
            'image': 'photo.png',
            'audio': 'audio.wav',
            'durationMs': 10000,
            'coverMs': 0,
            'captions': [
              {'startMs': 0, 'endMs': 5000, 'text': 'Synthetic caption'},
            ],
          }),
        );
      final output = Directory(p.join(temp.path, 'frames'))..createSync();
      final result = await Process.run(
        'flutter',
        ['test', '--no-pub', 'test/support/capture_http_attempt.dart'],
        environment: {
          'SOCIAL_STUDIO_JOB': job.path,
          'SOCIAL_STUDIO_SPEC': spec.path,
          'SOCIAL_STUDIO_FRAMES': output.path,
          'SOCIAL_STUDIO_FONT': p.absolute(
            '../../probes/phase0/assets/Roboto-Regular.ttf',
          ),
          'FLUTTER_SUPPRESS_ANALYTICS': 'true',
        },
      );
      expect(result.exitCode, 0, reason: '${result.stderr}\n${result.stdout}');
      expect(
        File(p.join(output.path, 'frames.rgba')).lengthSync(),
        96 * 160 * 4 * 20,
      );
      expect(
        File(p.join(output.path, 'captions.srt')).readAsStringSync(),
        contains('Synthetic caption'),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
