import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:social_studio/rendering.dart';
import 'package:social_studio/social_studio.dart';
import 'package:social_studio/src/story_encode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late Map<String, Object?> job;
  late File file;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('story-privacy-');
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
      ],
    };
  });
  tearDown(() => directory.deleteSync(recursive: true));

  StoryJob load() {
    file.writeAsStringSync(jsonEncode(job));
    return StoryJob.load(file.path, specDirectory: '../../spec/desktop-story');
  }

  Future<void> expectNoSocket(Future<void> Function() body) {
    return HttpOverrides.runZoned(
      body,
      createHttpClient: (SecurityContext? context) {
        throw StateError('A socket client was created.');
      },
    );
  }

  test('local image, audio, font and transcript paths are accepted', () async {
    final loaded = load();
    final font = File('${directory.path}/font.ttf')..writeAsBytesSync([0]);
    expect(await readLocalFont(font.path), [0]);
    expect(
      () =>
          buildStory(loaded, transcriptPath: '${directory.path}/captions.srt'),
      returnsNormally,
    );
  });

  for (final input in <String, String>{
    'image': 'https://example.invalid/photo.png',
    'image redirect': 'https://example.invalid/redirect',
    'image http redirect': 'http://example.invalid/redirect.png',
    'video url': 'https://example.invalid/clip.mp4',
    'audio': 'https://example.invalid/voice.wav',
    'audio redirect': 'https://example.invalid/redirect.wav',
  }.entries) {
    test('rejects remote ${input.key} before access', () async {
      final field = input.key.startsWith('audio') ? 'audio' : 'image';
      job[field] = input.value;
      await expectNoSocket(() async {
        expect(
          load,
          throwsA(
            isA<StoryJobException>().having(
              (StoryJobException error) => error.message,
              'message',
              contains('relative local paths'),
            ),
          ),
        );
      });
    });
  }

  test('rejects a remote video field before access', () async {
    job['video'] = 'https://example.invalid/clip.mp4';
    await expectNoSocket(() async {
      expect(load, throwsA(isA<StoryJobException>()));
    });
  });

  test('rejects remote font and transcript paths before access', () async {
    final loaded = load();
    await expectNoSocket(() async {
      await expectLater(
        readLocalFont('https://example.invalid/redirect.ttf'),
        throwsA(isA<StoryJobException>()),
      );
      expect(
        () => buildStory(
          loaded,
          transcriptPath: 'https://example.invalid/captions.srt',
        ),
        throwsA(isA<StoryJobException>()),
      );
      expect(
        () => buildStory(
          loaded,
          transcriptPath: 'http://example.invalid/redirect.srt',
        ),
        throwsA(isA<StoryJobException>()),
      );
    });
  });

  test(
    'empty allowlist detects image, video, audio and redirect fetches',
    () async {
      Future<FluvieRenderException> detected(
        Future<void> Function(MediaResolver resolver) attempt,
      ) async {
        final scope = resolverScope(
          null,
          networkAllowlist: const NetworkAllowlist(hosts: {}),
        );
        try {
          await attempt(scope.resolver);
          throw StateError('The network attempt was not detected.');
        } on FluvieRenderException catch (error) {
          return error;
        } finally {
          await scope.dispose();
        }
      }

      final image = await detected(
        (resolver) => resolver.preResolveAll([
          MediaSource.network(Uri.parse('https://example.invalid/photo.png')),
        ]),
      );
      final video = await detected(
        (resolver) => resolver.preResolveAll([
          MediaSource.network(Uri.parse('https://example.invalid/clip.mp4')),
        ]),
      );
      final redirect = await detected(
        (resolver) => resolver.preResolveAll([
          MediaSource.network(Uri.parse('https://example.invalid/redirect')),
        ]),
      );
      final audio = await detected(
        (resolver) => resolver.preResolveAudio([
          AudioSource.network(Uri.parse('https://example.invalid/voice.wav')),
        ]),
      );
      final httpRedirect = await detected(
        (resolver) => resolver.preResolveAudio([
          AudioSource.network(Uri.parse('http://example.invalid/redirect')),
        ]),
      );
      for (final error in [image, video, redirect, audio]) {
        expect(error.message, contains('Disallowed host'));
        expect(error.message, isNot(contains('Network fetch')));
      }
      expect(httpRedirect.message, contains('Disallowed URL scheme'));
      expect(httpRedirect.message, isNot(contains('Network fetch')));
    },
  );

  test('synthetic location and device tags are absent after metadata copying is disabled', () async {
    final ffmpeg = Platform.environment['FLUVIE_FFMPEG'] ?? 'ffmpeg';
    final ffprobe = _ffprobe(ffmpeg);
    final tagged = p.join(directory.path, 'tagged.mp4');
    final kept = p.join(directory.path, 'kept.mp4');
    final stripped = p.join(directory.path, 'stripped.mp4');
    final deviceKept = p.join(directory.path, 'device-kept.mp4');
    final deviceStripped = p.join(directory.path, 'device-stripped.mp4');
    await _run(ffmpeg, [
      '-y',
      '-hide_banner',
      '-loglevel',
      'error',
      '-f',
      'lavfi',
      '-i',
      'color=c=red:s=16x16:d=0.2',
      '-f',
      'lavfi',
      '-i',
      'anullsrc=r=44100:cl=mono',
      '-shortest',
      '-movflags',
      '+use_metadata_tags',
      '-metadata',
      'location=+00.0000+000.0000/',
      '-metadata',
      'make=PrivacyFixture',
      '-metadata',
      'model=PrivacyFixture',
      '-metadata',
      'device=PrivacyFixture',
      '-c:v',
      'libx264',
      '-c:a',
      'aac',
      tagged,
    ]);
    final fixture = await _tags(ffprobe, tagged);
    expect(fixture, contains('+00.0000+000.0000/'));
    expect(fixture, contains('PrivacyFixture'));

    Future<void> encode(
      String output, {
      required bool discard,
      bool keepDeviceTags = false,
    }) {
      return _run(ffmpeg, [
        '-y',
        '-hide_banner',
        '-loglevel',
        'error',
        '-i',
        tagged,
        '-map',
        '0:v:0',
        '-map',
        '0:a:0',
        if (discard) ...storyDiscardedMetadataArguments,
        '-c:v',
        'libx264',
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
        '-movflags',
        keepDeviceTags ? '+use_metadata_tags+faststart' : '+faststart',
        output,
      ]);
    }

    await encode(kept, discard: false);
    await encode(stripped, discard: true);
    await encode(deviceKept, discard: false, keepDeviceTags: true);
    await encode(deviceStripped, discard: true, keepDeviceTags: true);
    expect(await _tags(ffprobe, kept), contains('+00.0000+000.0000/'));
    expect(await _tags(ffprobe, deviceKept), contains('PrivacyFixture'));
    for (final output in [stripped, deviceStripped]) {
      final tags = await _tags(ffprobe, output);
      expect(tags, isNot(contains('+00.0000+000.0000/')));
      expect(tags, isNot(contains('PrivacyFixture')));
    }
    expect(
      _containsInOrder(
        storyVideoArguments(
          width: 16,
          height: 16,
          fps: 30,
          rawFrames: 'frames.rgba',
          audioPath: 'voice.wav',
          durationMs: 1000,
          outputPath: 'story.mp4',
        ),
        storyDiscardedMetadataArguments,
      ),
      isTrue,
    );
    expect(
      _containsInOrder(
        storyCoverArguments(
          videoPath: 'story.mp4',
          coverFrame: 0,
          outputPath: 'cover.png',
        ),
        storyDiscardedMetadataArguments,
      ),
      isTrue,
    );
  });
}

String _ffprobe(String ffmpeg) {
  final sibling = p.join(p.dirname(ffmpeg), 'ffprobe');
  if (p.basename(ffmpeg) != ffmpeg && File(sibling).existsSync()) {
    return sibling;
  }
  return 'ffprobe';
}

Future<String> _tags(String ffprobe, String media) async {
  final result = await Process.run(ffprobe, [
    '-v',
    'error',
    '-show_entries',
    'format_tags:stream_tags',
    '-of',
    'json',
    media,
  ]);
  if (result.exitCode != 0) {
    throw ProcessException(
      ffprobe,
      ['-show_entries'],
      '${result.stderr}',
      result.exitCode,
    );
  }
  final Object? decoded = jsonDecode(result.stdout.toString());
  if (decoded is Map) {
    final format = decoded['format'];
    if (format is Map) format.remove('filename');
  }
  return jsonEncode(decoded);
}

Future<void> _run(String command, List<String> arguments) async {
  final result = await Process.run(command, arguments);
  if (result.exitCode != 0) {
    throw ProcessException(
      command,
      arguments,
      '${result.stderr}',
      result.exitCode,
    );
  }
}

bool _containsInOrder(List<String> arguments, List<String> expected) {
  if (expected.isEmpty) return false;
  for (var start = 0; start <= arguments.length - expected.length; start++) {
    var matches = true;
    for (var index = 0; index < expected.length; index++) {
      if (arguments[start + index] != expected[index]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}
