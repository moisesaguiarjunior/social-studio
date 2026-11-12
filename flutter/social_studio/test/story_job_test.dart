import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:social_studio/social_studio.dart';

void main() {
  late Directory directory;
  late Map<String, Object?> job;
  late File file;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('story-job-test-');
    file = File('${directory.path}/job.json');
    File('${directory.path}/photo.png').writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aM1sAAAAASUVORK5CYII=',
      ),
    );
    File('${directory.path}/voice.wav').writeAsBytesSync([
      ...ascii.encode('RIFF'),
      4,
      0,
      0,
      0,
      ...ascii.encode('WAVE'),
    ]);
    job = {
      'version': 1,
      'template': 'story-photo-v1',
      'image': 'photo.png',
      'audio': 'voice.wav',
      'durationMs': 12000,
      'coverMs': 3000,
      'captions': [
        {'startMs': 1000, 'endMs': 5000, 'text': 'Synthetic caption'},
        {'startMs': 6000, 'endMs': 11000, 'text': 'Another cue'},
      ],
    };
  });
  tearDown(() => directory.deleteSync(recursive: true));

  StoryJob load() {
    file.writeAsStringSync(jsonEncode(job));
    return StoryJob.load(file.path, specDirectory: '../../spec/desktop-story');
  }

  test('valid local job becomes supplied timed SRT', () {
    final result = load();
    expect(
      result.toSrt(),
      contains('00:00:01,000 --> 00:00:05,000\nSynthetic caption'),
    );
    expect(
      result.toSrt(),
      contains('00:00:06,000 --> 00:00:11,000\nAnother cue'),
    );
    expect(
      result.scenes.single.imagePath,
      File('${directory.path}/photo.png').resolveSymbolicLinksSync(),
    );
  });

  for (final change in <String, Object?>{
    'version': 2,
    'template': 'unknown',
    'durationMs': 20000,
    'coverMs': 12000,
    'captions': <Object?>[],
    'unexpected': true,
  }.entries) {
    test('rejects unsupported ${change.key}', () {
      job[change.key] = change.value;
      expect(load, throwsA(isA<StoryJobException>()));
    });
  }

  for (final path in [
    'https://example.invalid/a.png',
    '//example.invalid/a.png',
    'file:///tmp/a.png',
    '/tmp/a.png',
    'missing.png',
  ]) {
    test('rejects nonlocal or missing input $path', () {
      job['image'] = path;
      expect(load, throwsA(isA<StoryJobException>()));
    });
  }

  test('rejects overlapping cues and subtitle control text', () {
    job['captions'] = [
      {'startMs': 1000, 'endMs': 5000, 'text': 'One'},
      {'startMs': 4000, 'endMs': 9000, 'text': 'Two'},
    ];
    expect(load, throwsA(isA<StoryJobException>()));
    job['captions'] = [
      {
        'startMs': 0,
        'endMs': 1000,
        'text': 'One\n\n2\n00:00:01,000 --> 00:00:02,000',
      },
    ];
    expect(load, throwsA(isA<StoryJobException>()));
  });

  test('rejects partial-frame duration and cues outside duration', () {
    job['durationMs'] = 12001;
    expect(load, throwsA(isA<StoryJobException>()));
    job['durationMs'] = 12000;
    job['captions'] = [
      {'startMs': 11000, 'endMs': 13000, 'text': 'Late'},
    ];
    expect(load, throwsA(isA<StoryJobException>()));
  });

  test('rejects playlists and nonimage files before rendering', () {
    File('${directory.path}/voice.wav')
        .writeAsStringSync('https://example.invalid/audio');
    expect(load, throwsA(isA<StoryJobException>()));
    File('${directory.path}/voice.wav').writeAsBytesSync([
      ...ascii.encode('RIFF'),
      4,
      0,
      0,
      0,
      ...ascii.encode('WAVE'),
    ]);
    File('${directory.path}/photo.png').writeAsStringSync('<svg/>');
    expect(load, throwsA(isA<StoryJobException>()));
  });

  test('rejects cues that collapse under frame quantization', () {
    job['captions'] = [
      {'startMs': 1000, 'endMs': 1001, 'text': 'Too short'},
    ];
    expect(load, throwsA(isA<StoryJobException>()));
    job['captions'] = [
      {'startMs': 2034, 'endMs': 2050, 'text': 'Rounding boundary'},
    ];
    expect(load, throwsA(isA<StoryJobException>()));
    job['captions'] = [
      {'startMs': 1000, 'endMs': 1017, 'text': 'One frame'},
    ];
    expect(load, returnsNormally);
  });

  test('failed temporary setup removes staging', () async {
    load();
    final result = await Process.run(
      'dart',
      [
        'run',
        'bin/social_studio.dart',
        'render',
        file.path,
        '${directory.path}/output',
      ],
      environment: {'TMPDIR': '${directory.path}/unavailable'},
    );
    expect(result.exitCode, 1);
    expect(
      result.stderr,
      anyOf(contains('PathNotFoundException'), contains('FileSystemException')),
    );
    expect(result.stderr, contains('unavailable'));
    expect(Directory('${directory.path}/output').existsSync(), isFalse);
    expect(
      directory.listSync().where(
        (entry) => entry.path.contains('.social-studio-'),
      ),
      isEmpty,
    );
  });

  test(
    'media integrity rejects changed images, changed audio and removed files',
    () {
      for (final name in ['photo.png', 'voice.wav']) {
        final input = File('${directory.path}/$name');
        final original = input.readAsBytesSync();
        final validated = load();
        expect(validated.verifyMediaUnchanged, returnsNormally);
        input.writeAsBytesSync([...original, 0]);
        expect(
          validated.verifyMediaUnchanged,
          throwsA(isA<StoryJobException>()),
        );
        input.writeAsBytesSync(original);
        expect(validated.verifyMediaUnchanged, returnsNormally);
        input.deleteSync();
        expect(
          validated.verifyMediaUnchanged,
          throwsA(isA<StoryJobException>()),
        );
        input.writeAsBytesSync(original);
      }
    },
  );

  test('schema integer accepts integral JSON number', () {
    job['durationMs'] = 12000.0;
    expect(load, returnsNormally);
  });

  void sequence() {
    job.remove('image');
    job['scenes'] = [
      {'image': 'photo.png', 'durationMs': 4000},
      {'image': 'photo.png', 'durationMs': 8000},
    ];
  }

  test('accepts a photo sequence with captions across the cut', () {
    sequence();
    final result = load();
    expect(result.durationMs, 12000);
    expect(result.scenes.map((scene) => scene.durationMs), [4000, 8000]);
    expect(load().toSrt(), contains('00:00:01,000 --> 00:00:05,000'));
  });

  test('requires exactly one image or scene list', () {
    sequence();
    expect(load, returnsNormally);
    job['image'] = 'photo.png';
    expect(load, throwsA(isA<StoryJobException>()));
    job.remove('image');
    job.remove('scenes');
    expect(load, throwsA(isA<StoryJobException>()));
  });

  test('scene durations must sum to the job and contain whole frames', () {
    sequence();
    expect(load, returnsNormally);
    for (final durations in [
      [4000, 7000],
      [4001, 7999],
      [0, 12000],
    ]) {
      job['scenes'] = [
        for (final duration in durations)
          {'image': 'photo.png', 'durationMs': duration},
      ];
      expect(load, throwsA(isA<StoryJobException>()));
    }
  });

  test('validates media in every scene before rendering', () {
    sequence();
    expect(load, returnsNormally);
    File('${directory.path}/invalid.png').writeAsStringSync('<svg/>');
    for (final path in [
      'missing.png',
      'https://example.invalid/photo.png',
      'invalid.png',
    ]) {
      job['scenes'] = [
        {'image': 'photo.png', 'durationMs': 4000},
        {'image': path, 'durationMs': 8000},
      ];
      expect(load, throwsA(isA<StoryJobException>()));
    }
  });

  test('rejects empty and oversized sequences and unknown scene options', () {
    sequence();
    expect(load, returnsNormally);
    for (final scenes in <List<Object?>>[
      [],
      [
        ...List.filled(12, {'image': 'photo.png', 'durationMs': 100}),
        {'image': 'photo.png', 'durationMs': 10800},
      ],
      [
        {'image': 'photo.png', 'durationMs': 12000, 'transition': 'unknown'},
      ],
    ]) {
      job['scenes'] = scenes;
      expect(load, throwsA(isA<StoryJobException>()));
    }
  });
}
