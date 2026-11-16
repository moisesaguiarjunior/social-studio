import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart';
import 'package:social_studio/rendering.dart';
import 'package:social_studio/social_studio.dart';
import 'package:social_studio/src/story_craft.dart';

import 'support/desktop_checkout.dart';

import '../tool/capture_frame_pump.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late Map<String, Object?> job;
  late File source;
  late Directory spec;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('crafted-story-');
    spec = Directory('${temp.path}/spec');
    void copy(Directory from, Directory to) {
      to.createSync(recursive: true);
      for (final entry in from.listSync()) {
        final target =
            '${to.path}/${entry.uri.pathSegments.where((s) => s.isNotEmpty).last}';
        if (entry is Directory) copy(entry, Directory(target));
        if (entry is File) entry.copySync(target);
      }
    }

    copy(Directory('../../spec/desktop-story'), spec);
    void data(String name, Map<String, Object?> changes) {
      final file = File('${spec.path}/$name.json');
      final Object? decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, Object?>) throw StateError('Expected object');
      file.writeAsStringSync(jsonEncode({...decoded, ...changes}));
    }

    data('story-profile', {'width': 96, 'height': 160});
    data('v2/story-template', {'captionFontSize': 12, 'captionInset': 4});
    File(
      '${temp.path}/photo.png',
    ).writeAsBytesSync(File('test/fixtures/tagged_red.png').readAsBytesSync());
    File('${temp.path}/tone.wav').writeAsBytesSync([
      ...ascii.encode('RIFF'),
      4,
      0,
      0,
      0,
      ...ascii.encode('WAVE'),
    ]);
    job = {
      'version': 2,
      'template': 'story-craft-v1',
      'image': 'photo.png',
      'audio': 'tone.wav',
      'durationMs': 12000,
      'coverMs': 3000,
      'captions': [
        {'startMs': 1000, 'endMs': 5000, 'text': 'Synthetic caption'},
      ],
      'craft': {
        'material': 'paper',
        'color': '#EEE8DD',
        'seed': 23,
        'grainScale': 1,
        'grainStrength': .7,
        'frameInset': .12,
        'edge': 'cut',
        'stitch': 'running',
      },
    };
    source = File('${temp.path}/job.json');
  });
  tearDown(() => temp.deleteSync(recursive: true));
  StoryJob load() {
    source.writeAsStringSync(jsonEncode(job));
    return StoryJob.load(source.path, specDirectory: spec.path);
  }

  test('crafted snapshots retain recipe and version without weakening v1', () {
    final validated = load();
    final snapshot = validated.writeSnapshot('${temp.path}/frozen');
    job['craft'] = {'material': 'not-allowed'};
    source.writeAsStringSync(jsonEncode(job));
    final replay = StoryJob.load(
      snapshot,
      specDirectory: '${temp.path}/frozen',
    );
    expect(replay.craft, validated.craft);
    expect(replay.version, 2);
    expect(replay.toSrt(), validated.toSrt());
    expect(replay.verifyMediaUnchanged, returnsNormally);
    job['version'] = 1;
    job['template'] = 'story-photo-v1';
    expect(load, throwsA(isA<StoryJobException>()));
    job.remove('craft');
    expect(load, returnsNormally);
  });
  test(
    'unsupported material fields, limits and versions fail before capture',
    () {
      final original = Map<String, Object?>.from(job);
      final Object? raw = job['craft'];
      if (raw is! Map<String, Object?>) throw StateError('Expected recipe');
      for (final change in <String, Object?>{
        'material': 'https://example.invalid/texture.png',
        'grainScale': 4.1,
        'grainStrength': -1,
        'seed': -1,
        'frameInset': .5,
        'edge': 'unknown',
        'stitch': 'unknown',
        'callback': 'code',
      }.entries) {
        job = {
          ...original,
          'craft': {...raw, change.key: change.value},
        };
        expect(load, throwsA(isA<StoryJobException>()), reason: change.key);
      }
      job = {...original, 'version': 999};
      expect(load, throwsA(isA<StoryJobException>()));
      job = original;
      final profile = File('${spec.path}/story-profile.json');
      final Object? decoded = jsonDecode(profile.readAsStringSync());
      if (decoded is! Map<String, Object?>) {
        throw StateError('Expected profile');
      }
      profile.writeAsStringSync(jsonEncode({...decoded, 'width': 2050}));
      expect(load, throwsA(isA<StoryJobException>()));
    },
  );
  test(
    'large square seam limits fail before capture without clamping the recipe',
    () {
      final profile = File('${spec.path}/story-profile.json');
      final Object? decoded = jsonDecode(profile.readAsStringSync());
      if (decoded is! Map<String, Object?>) {
        throw StateError('Expected profile');
      }
      profile.writeAsStringSync(
        jsonEncode({...decoded, 'width': 1536, 'height': 1536}),
      );
      final Object? recipe = job['craft'];
      if (recipe is! Map<String, Object?>) {
        throw StateError('Expected recipe');
      }
      job['craft'] = {...recipe, 'frameInset': .18};
      expect(load, throwsA(isA<StoryJobException>()));
      job['craft'] = {...recipe, 'frameInset': .16};
      final accepted = load();
      expect(
        () => CraftStorySurface(
          recipe: accepted.craft!,
          width: 1536,
          height: 1536,
          child: const SizedBox(),
        ),
        returnsNormally,
      );
      job['craft'] = {...recipe, 'frameInset': .18, 'stitch': 'none'};
      expect(load, returnsNormally);
    },
  );
  test('actual crafted CLI exports MP4 cover subtitles and review with the existing offline transaction', () async {
    final package = createDesktopCheckout(Directory('${temp.path}/checkout'));
    final profile = File(
      '${temp.path}/checkout/spec/desktop-story/story-profile.json',
    );
    final Object? rawProfile = jsonDecode(profile.readAsStringSync());
    if (rawProfile is! Map<String, Object?>) {
      throw StateError('Expected profile');
    }
    profile.writeAsStringSync(jsonEncode({...rawProfile, 'fps': 2}));
    final template = File(
      '${temp.path}/checkout/spec/desktop-story/v2/story-template.json',
    );
    final Object? rawTemplate = jsonDecode(template.readAsStringSync());
    if (rawTemplate is! Map<String, Object?>) {
      throw StateError('Expected template');
    }
    template.writeAsStringSync(
      jsonEncode({...rawTemplate, 'captionFontSize': 12, 'captionInset': 4}),
    );
    final samples = List<int>.filled(8000 * 12 * 2, 0);
    final audio = ByteData(44 + samples.length);
    void asciiAt(int n, String value) {
      for (var i = 0; i < value.length; i++) {
        audio.setUint8(n + i, value.codeUnitAt(i));
      }
    }

    asciiAt(0, 'RIFF');
    audio.setUint32(4, 36 + samples.length, Endian.little);
    asciiAt(8, 'WAVE');
    asciiAt(12, 'fmt ');
    audio.setUint32(16, 16, Endian.little);
    audio.setUint16(20, 1, Endian.little);
    audio.setUint16(22, 1, Endian.little);
    audio.setUint32(24, 8000, Endian.little);
    audio.setUint32(28, 16000, Endian.little);
    audio.setUint16(32, 2, Endian.little);
    audio.setUint16(34, 16, Endian.little);
    asciiAt(36, 'data');
    audio.setUint32(40, samples.length, Endian.little);
    File('${temp.path}/tone.wav').writeAsBytesSync(audio.buffer.asUint8List());
    source.writeAsStringSync(jsonEncode(job));
    final output = '${temp.path}/export';
    final result = await Process.run('dart', [
      'run',
      'bin/social_studio.dart',
      'render',
      source.path,
      output,
    ], workingDirectory: package.path);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    for (final name in [
      'story.mp4',
      'cover.png',
      'captions.srt',
      'review.html',
      'result.json',
    ]) {
      expect(File('$output/$name').lengthSync(), greaterThan(0), reason: name);
    }
    final probe = await Process.run('ffprobe', [
      '-v',
      'error',
      '-show_entries',
      'stream=codec_name,width,height,nb_frames',
      '-of',
      'json',
      '$output/story.mp4',
    ]);
    expect(probe.exitCode, 0);
    expect(probe.stdout, contains('h264'));
    expect(probe.stdout, contains('aac'));
    expect(probe.stdout, contains('"nb_frames": "24"'));
    expect(
      File('$output/captions.srt').readAsStringSync(),
      contains('Synthetic caption'),
    );
    expect(
      File('$output/review.html').readAsStringSync(),
      contains('story.mp4'),
    );
  }, timeout: const Timeout(Duration(minutes: 4)));
  testWidgets(
    'narrow tall surfaces keep all stitch choices inside the work budget',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(64, 2048);
      tester.view.devicePixelRatio = 1;
      final recipe = load().craft;
      if (recipe == null) throw StateError('Expected validated recipe');
      for (final stitch in [
        'none',
        'running',
        'backstitch',
        'blanket',
        'chain',
        'cross',
        'basting',
      ]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CraftStorySurface(
              recipe: {...recipe, 'stitch': stitch},
              width: 64,
              height: 2048,
              child: const SizedBox.expand(),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: stitch);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'real Fluvie capture sees media inside the material and replays identical frames',
    (tester) async {
      final loader = FontLoader('Roboto')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File('../../probes/phase0/assets/Roboto-Regular.ttf')
                  .readAsBytesSync(),
            ),
          ),
        );
      await loader.load();
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder)
          ..drawColor(const ui.Color(0xFFFF0000), ui.BlendMode.src);
        canvas.drawRect(
          const ui.Rect.fromLTWH(5, 3, 6, 6),
          ui.Paint()..color = const ui.Color(0xFFFFC040),
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(16, 16);
        try {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          if (png == null) {
            throw StateError('Could not encode diagnostic photo');
          }
          File('${temp.path}/photo.png').writeAsBytesSync(
            png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
          );
        } finally {
          image.dispose();
          picture.dispose();
        }
      });
      final validated = load();
      final transcript = File('${temp.path}/captions.srt')
        ..writeAsStringSync(validated.toSrt());
      Future<List<int>> capture(String name) async {
        final scope = resolverScope(
          null,
          networkAllowlist: const NetworkAllowlist(hosts: {}),
        );
        try {
          final output = Directory('${temp.path}/$name')..createSync();
          final video = buildStory(validated, transcriptPath: transcript.path);
          final manifest = await renderVideo(
            video: video,
            outDir: output,
            cacheEnabled: false,
            resolver: scope.resolver,
            defaultFontFamily: 'Roboto',
            pumpWidget: tester.pumpWidget,
            pumpFrame: captureFramePump(fps: video.fps, pump: tester.pump),
            runAsync: tester.runAsync,
            setViewSize: (w, h) {
              tester.view.physicalSize = Size(w.toDouble(), h.toDouble());
              tester.view.devicePixelRatio = 1;
            },
          );
          expect(manifest.frameCount, 360);
          final bytes = File('${output.path}/${manifest.framesFileName}')
              .readAsBytesSync();
          await tester.pumpWidget(const SizedBox());
          return bytes;
        } finally {
          scope.dispose();
        }
      }

      final first = await capture('first');
      final second = await capture('second');
      expect(first, second);
      const stride = 96 * 160 * 4;
      expect(first.length, stride * 360);
      expect(
        first.sublist(0, stride),
        isNot(first.sublist(20 * stride, 21 * stride)),
        reason:
            'Photo motion follows the existing frame timeline before captions',
      );
      int rgb(int x, int y) {
        final n = (y * 96 + x) * 4;
        return first[n] << 16 | first[n + 1] << 8 | first[n + 2];
      }

      expect(
        rgb(48, 24),
        0xFF0000,
        reason: 'Declared Fluvie media resolved inside the custom surface',
      );
      expect(
        rgb(2, 2),
        isNot(0xFF0000),
        reason: 'Material remains outside the photo opening',
      );
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
