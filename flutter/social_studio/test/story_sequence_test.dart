import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart';
import 'package:social_studio/rendering.dart';
import 'package:social_studio/social_studio.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final loader = FontLoader('Roboto')
    ..addFont(
      Future<ByteData>.value(
        ByteData.sublistView(
          File('../../probes/phase0/assets/Roboto-Regular.ttf')
              .readAsBytesSync(),
        ),
      ),
    );
  await loader.load();

  testWidgets('photo cuts preserve global captions and exact frame count', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('story-sequence-');
    addTearDown(() => directory.deleteSync(recursive: true));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final spec = Directory('${directory.path}/spec')..createSync();
    for (final entry in Directory(
      '../../spec/desktop-story',
    ).listSync().whereType<File>()) {
      entry.copySync('${spec.path}/${entry.uri.pathSegments.last}');
    }
    // A tiny diagnostic canvas keeps this real-renderer test inexpensive.
    // The public profile is unchanged; these are synthetic test fixtures.
    void overrideData(String name, Map<String, Object?> changes) {
      final file = File('${spec.path}/$name.json');
      final Object? decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, Object?>) throw StateError('Expected object');
      file.writeAsStringSync(jsonEncode({...decoded, ...changes}));
    }

    overrideData('story-profile', {'width': 96, 'height': 160});
    overrideData('story-template', {'captionFontSize': 12, 'captionInset': 4});
    const colors = [0xFFD03030, 0xFF30A050, 0xFF3050C0];
    await tester.runAsync(() async {
      for (var i = 0; i < colors.length; i++) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawColor(ui.Color(colors[i]), ui.BlendMode.src);
        canvas.drawRect(
          const ui.Rect.fromLTWH(24, 24, 24, 24),
          ui.Paint()..color = const ui.Color(0xFFFFC040),
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(96, 160);
        try {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          if (png == null) throw StateError('Could not encode fixture');
          File('${directory.path}/$i.png').writeAsBytesSync(
            png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
          );
        } finally {
          image.dispose();
          picture.dispose();
        }
      }
    });
    File('${directory.path}/tone.wav').writeAsBytesSync([
      ...ascii.encode('RIFF'),
      4,
      0,
      0,
      0,
      ...ascii.encode('WAVE'),
    ]);
    final source = File('${directory.path}/job.json')
      ..writeAsStringSync(
        jsonEncode({
          'version': 1,
          'template': 'story-photo-v1',
          'scenes': [
            for (var i = 0; i < colors.length; i++)
              {'image': '$i.png', 'durationMs': 4000},
          ],
          'audio': 'tone.wav',
          'durationMs': 12000,
          'coverMs': 4000,
          'captions': [
            {'startMs': 3500, 'endMs': 4500, 'text': 'Across the cut'},
          ],
        }),
      );
    final job = StoryJob.load(source.path, specDirectory: spec.path);
    final transcript = File('${directory.path}/captions.srt')
      ..writeAsStringSync(job.toSrt());
    final scope = resolverScope(
      null,
      networkAllowlist: const NetworkAllowlist(hosts: {}),
    );
    addTearDown(scope.dispose);
    final out = Directory('${directory.path}/frames')..createSync();
    final manifest = await renderVideo(
      video: buildStory(job, transcriptPath: transcript.path),
      outDir: out,
      resolver: scope.resolver,
      defaultFontFamily: 'Roboto',
      pumpWidget: tester.pumpWidget,
      pumpFrame: () => tester.pump(),
      runAsync: tester.runAsync,
      setViewSize: (width, height) {
        tester.view.physicalSize = Size(width.toDouble(), height.toDouble());
        tester.view.devicePixelRatio = 1;
      },
    );
    expect(manifest.frameCount, 360);
    final bytes = File('${out.path}/${manifest.framesFileName}')
        .readAsBytesSync();
    const stride = 96 * 160 * 4;
    expect(bytes.length, stride * 360);
    int rgb(int frame, int x, int y) {
      final offset = frame * stride + (y * 96 + x) * 4;
      return bytes[offset] << 16 | bytes[offset + 1] << 8 | bytes[offset + 2];
    }

    for (final frame in [0, 119, 120, 239, 240, 359]) {
      expect(
        rgb(frame, 2, 2),
        colors[frame ~/ 120] & 0xFFFFFF,
        reason: 'Photo at frame $frame',
      );
    }
    int whiteInk(int frame) {
      var count = 0;
      for (var y = 85; y < 150; y++) {
        for (var x = 4; x < 92; x++) {
          final pixel = rgb(frame, x, y);
          if ((pixel >> 16) > 220 &&
              ((pixel >> 8) & 255) > 220 &&
              (pixel & 255) > 220) {
            count++;
          }
        }
      }
      return count;
    }

    for (final frame in [105, 119, 120, 134]) {
      expect(
        whiteInk(frame),
        greaterThan(10),
        reason: 'Caption at frame $frame',
      );
    }
    for (final frame in [104, 135, 239, 240]) {
      expect(whiteInk(frame), 0, reason: 'No caption at frame $frame');
    }
    expect(
      bytes.sublist(0, stride),
      isNot(equals(bytes.sublist(100 * stride, 101 * stride))),
      reason: 'Photo motion advances before any caption appears',
    );
  });
}
