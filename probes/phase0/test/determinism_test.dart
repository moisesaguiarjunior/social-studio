import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:phase0_probe/determinism_video.dart';

/// Captures [video] to a fresh directory and returns the raw RGBA frames.
///
/// The font is already registered by [main]. File IO and `toImage` still need
/// [WidgetTester.runAsync]: the test binding's fake clock never completes them.
Future<Uint8List> _capture(WidgetTester tester, Video video) async {
  final out = await tester.runAsync(
    () => Directory.systemTemp.createTemp('phase0-frames-'),
  );
  if (out == null) {
    throw StateError('Could not create a temp directory.');
  }
  addTearDown(() async {
    if (out.existsSync()) {
      out.deleteSync(recursive: true);
    }
  });
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final manifest = await renderVideo(
    video: video,
    outDir: out,
    defaultFontFamily: 'Roboto',
    pumpWidget: tester.pumpWidget,
    pumpFrame: () => tester.pump(),
    setViewSize: (int width, int height) {
      tester.view.physicalSize = Size(width.toDouble(), height.toDouble());
      tester.view.devicePixelRatio = 1;
    },
    runAsync: tester.runAsync,
  );

  expect(manifest.width, 1080);
  expect(manifest.height, 1920);
  expect(manifest.fps, 30);
  expect(manifest.frameCount, 60);
  expect(manifest.ffmpegArgs, contains('libx264'));

  final frames = File('${out.path}/${manifest.framesFileName}');
  final bytes = await tester.runAsync(frames.readAsBytes);
  if (bytes == null) {
    throw StateError('Could not read the captured frames.');
  }
  expect(bytes.length, 1080 * 1920 * 4 * 60);
  return bytes;
}

/// Reads one RGBA pixel as a 24-bit RGB value.
int _rgb(Uint8List frames, int width, int frame, int x, int y) {
  final frameBytes = width * 1920 * 4;
  final index = frame * frameBytes + (y * width + x) * 4;
  return (frames[index] << 16) | (frames[index + 1] << 8) | frames[index + 2];
}

/// Counts pixels inside a box that are not [background].
int _differing(
  Uint8List frames,
  int width,
  int frame,
  int background,
  Rect box,
) {
  var count = 0;
  final left = box.left.toInt();
  final top = box.top.toInt();
  final right = box.right.toInt();
  final bottom = box.bottom.toInt();
  for (var y = top; y < bottom; y++) {
    for (var x = left; x < right; x++) {
      if (_rgb(frames, width, frame, x, y) != background) {
        count++;
      }
    }
  }
  return count;
}

/// Decodes one captured RGBA frame for comparison or evidence export.
Future<ui.Image> _frameImage(Uint8List frames, int frame) async {
  const width = 1080;
  const height = 1920;
  final frameBytes = width * height * 4;
  final slice = frames.sublist(frame * frameBytes, (frame + 1) * frameBytes);
  final buffer = await ui.ImmutableBuffer.fromUint8List(slice);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
  }
}

/// Writes evidence without changing the committed visual references.
Future<void> _writePng(Uint8List frames, int frame, String path) async {
  final image = await _frameImage(frames, frame);
  try {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) {
      throw StateError('Could not encode frame $frame as PNG.');
    }
    await File(path).writeAsBytes(png.buffer.asUint8List());
  } finally {
    image.dispose();
  }
}

/// Proves two headless captures of the synthetic story match, frame for frame.
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Register Roboto before any test. [FontLoader.load] goes through
  // `loadFontFromList`, which does not complete under the fake clock, including
  // when called from inside `runAsync`.
  final font = await File('assets/Roboto-Regular.ttf').readAsBytes();
  final loader = FontLoader('Roboto')
    ..addFont(Future<ByteData>.value(ByteData.sublistView(font)));
  await loader.load();
  // ignore: avoid_print
  print('phase0 font loaded ${font.length} bytes');

  testWidgets('two captures of the 2s story are byte-identical', (
    tester,
  ) async {
    final first = await _capture(tester, determinismVideo());
    // ignore: avoid_print
    print('phase0 capture 1 bytes ${first.length}');
    final second = await _capture(tester, determinismVideo());
    // ignore: avoid_print
    print('phase0 capture 2 bytes ${second.length}');

    expect(sha256.convert(first).toString(), sha256.convert(second).toString());
    expect(first, second);

    const background = 0xE23D3D;
    expect(_rgb(first, 1080, 0, 540, 960), background);

    final textPixels = _differing(
      first,
      1080,
      0,
      background,
      const Rect.fromLTRB(300, 350, 780, 560),
    );
    expect(
      textPixels,
      greaterThan(50),
      reason: 'text run Ag Á should paint inside the inset',
    );
    // ignore: avoid_print
    print('phase0 text pixels $textPixels sha ${sha256.convert(first)}');

    final frameBytes = 1080 * 1920 * 4;
    final frame0 = first.sublist(0, frameBytes);
    final frame59 = first.sublist(59 * frameBytes, 60 * frameBytes);
    expect(frame0, isNot(equals(frame59)), reason: 'the rectangle should move');

    // Reuse the reviewed reference frames; repeatability alone accepts a
    // consistently wrong scene. Never update these to accommodate a failure.
    for (final frame in [0, 59]) {
      final image = await tester.runAsync(() => _frameImage(first, frame));
      if (image == null) {
        throw StateError('Could not decode frame $frame.');
      }
      try {
        await expectLater(
          image,
          matchesGoldenFile('../evidence/frame$frame.png'),
        );
      } finally {
        image.dispose();
      }
    }

    final evidence = Platform.environment['PHASE0_EVIDENCE'];
    if (evidence != null && evidence.isNotEmpty) {
      await tester.runAsync(() async {
        await Directory(evidence).create(recursive: true);
        await _writePng(first, 0, '$evidence/frame0.png');
        await _writePng(first, 59, '$evidence/frame59.png');
        await File('$evidence/sha256.txt')
            .writeAsString('${sha256.convert(first)}\n');
      });
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
