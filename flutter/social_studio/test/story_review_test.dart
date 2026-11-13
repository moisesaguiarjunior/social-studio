import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';
import 'package:social_studio/social_studio.dart';
import 'package:social_studio/src/story_review.dart';

void main() {
  late Directory directory;
  late Map<String, Object?> data;
  final template = File('assets/review.html').readAsStringSync();

  setUp(() {
    directory = Directory.systemTemp.createTempSync('story-review-');
    File('${directory.path}/photo.png')
        .writeAsBytesSync([137, 80, 78, 71, 13, 10, 26, 10]);
    File('${directory.path}/voice.wav').writeAsBytesSync([
      ...ascii.encode('RIFF'),
      4,
      0,
      0,
      0,
      ...ascii.encode('WAVE'),
    ]);
    data = {
      'version': 1,
      'template': 'story-photo-v1',
      'scenes': [
        {'image': 'photo.png', 'durationMs': 4000},
        {'image': 'photo.png', 'durationMs': 8000},
      ],
      'audio': 'voice.wav',
      'durationMs': 12000,
      'coverMs': 5000,
      'captions': [
        {'startMs': 1050, 'endMs': 2250, 'text': 'A synthetic moment'},
      ],
    };
  });
  tearDown(() => directory.deleteSync(recursive: true));

  String page({String? source}) {
    final file = File('${directory.path}/job.json')
      ..writeAsStringSync(jsonEncode(data));
    final job = StoryJob.load(
      file.path,
      specDirectory: '../../spec/desktop-story',
    );
    return buildStoryReview(job, template: source ?? template);
  }

  test('review navigation uses scene offsets and quantized caption frames', () {
    final html = page();
    expect(html, contains('data-start-frame="0" data-end-frame="120"'));
    expect(html, contains('data-start-frame="120" data-end-frame="360"'));
    expect(html, contains('data-start-frame="32" data-end-frame="68"'));
    expect(html, contains('00:04.000 – 00:12.000'));
    expect(html, isNot(contains('{{SCENES}}')));
    expect(html, isNot(contains(directory.path)));
    expect(html, isNot(contains('photo.png')));
    expect(html, isNot(contains('voice.wav')));
  });

  test('supplied markup is text and template-like captions stay literal', () {
    const text = '</span><script>globalThis.injected=true</script> & {{FPS}}';
    data['captions'] = [
      {'startMs': 1000, 'endMs': 5000, 'text': text},
    ];
    final html = page();
    expect(
      html,
      contains(
        '&lt;/span&gt;&lt;script&gt;globalThis.injected=true&lt;/script&gt; &amp; {{FPS}}',
      ),
    );
    expect(html, isNot(contains(text)));
    expect(RegExp('<script>').allMatches(html).length, 1);
    expect(RegExp('</script>').allMatches(html).length, 1);
  });

  test('fractional scene lengths retain exact frame navigation', () {
    data['scenes'] = [
      {'image': 'photo.png', 'durationMs': 2500},
      {'image': 'photo.png', 'durationMs': 9500},
    ];
    final html = page();
    expect(html, contains('data-start-frame="0" data-end-frame="75"'));
    expect(html, contains('data-start-frame="75" data-end-frame="360"'));
    final lengths = <double>[];
    for (final match in RegExp(
      r'<span class="length">([0-9.]+) s</span>',
    ).allMatches(html)) {
      final text = match.group(1);
      if (text == null) fail('Missing scene duration.');
      lengths.add(double.parse(text));
    }
    expect(lengths, [2.5, 9.5]);
  });

  test(
    'an unknown review slot fails instead of publishing unresolved markup',
    () {
      expect(() => page(source: '{{WIDTH}}'), returnsNormally);
      expect(
        () => page(source: '{{UNSUPPORTED_SLOT}}'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'template diagnostic',
            contains('Unknown review template slot'),
          ),
        ),
      );
    },
  );

  test(
    'result schema rejects incomplete exports and nonlocal artifact links',
    () {
      final schema = JsonSchema.create(
        File('../../spec/desktop-story/story-result.schema.json')
            .readAsStringSync(),
      );
      final result = <String, Object?>{
        'version': 1,
        'video': 'story.mp4',
        'cover': 'cover.png',
        'captions': 'captions.srt',
        'review': 'review.html',
        'width': 1080,
        'height': 1920,
        'fps': 30,
        'durationMs': 12000,
      };
      expect(schema.validate(result).isValid, isTrue);
      final missing = {...result}..remove('review');
      expect(schema.validate(missing).isValid, isFalse);
      expect(
        schema.validate({
          ...result,
          'video': 'https://example.invalid/story.mp4',
        }).isValid,
        isFalse,
      );
      expect(
        schema.validate({...result, 'source': '/private/input.png'}).isValid,
        isFalse,
      );
    },
  );

  test('single-image review has one full-duration scene', () {
    data.remove('scenes');
    data['image'] = 'photo.png';
    final html = page();
    expect(html, contains('data-start-frame="0" data-end-frame="360"'));
    expect(html, isNot(contains('Scene 2')));
  });
}
