import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart';
import 'package:lottie/lottie.dart';
import 'package:phase0_probe/lottie_video.dart';

/// Captures the Lottie-in-Fluvie probe and returns the raw frames.
///
/// [step] is the duration passed to `tester.pump`. The CLI harness uses
/// [Duration.zero], which does not advance a Lottie `AnimationController`.
Future<Uint8List> _capture(
  WidgetTester tester,
  String json, {
  Duration step = Duration.zero,
}) async {
  final out = await tester.runAsync(
    () => Directory.systemTemp.createTemp('phase0-lottie-'),
  );
  if (out == null) {
    throw StateError('Could not create a temp directory.');
  }
  addTearDown(() {
    if (out.existsSync()) {
      out.deleteSync(recursive: true);
    }
  });
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final manifest = await renderVideo(
    video: lottieVideo(json),
    outDir: out,
    pumpWidget: tester.pumpWidget,
    pumpFrame: () => tester.pump(step),
    setViewSize: (int width, int height) {
      tester.view.physicalSize = Size(width.toDouble(), height.toDouble());
      tester.view.devicePixelRatio = 1;
    },
    runAsync: tester.runAsync,
  );
  expect(manifest.frameCount, 30);
  final bytes = await tester.runAsync(
    () => File('${out.path}/${manifest.framesFileName}').readAsBytes(),
  );
  if (bytes == null) {
    throw StateError('Could not read the captured frames.');
  }
  return bytes;
}

/// Pixels inside the centered 400×400 Lottie box that are not the red field.
int _painted(Uint8List frames, int frame) {
  const width = 1080;
  const height = 1920;
  const frameBytes = width * height * 4;
  var count = 0;
  for (var y = 760; y < 1160; y++) {
    final row = frame * frameBytes + (y * width + 340) * 4;
    for (var x = 0; x < 400; x++) {
      final i = row + x * 4;
      if (frames[i] != 0xE2 || frames[i + 1] != 0x3D || frames[i + 2] != 0x3D) {
        count++;
      }
    }
  }
  return count;
}

/// How many pixels in the centered 400×400 Lottie box differ between two frames.
int _boxDelta(Uint8List frames, int frameA, int frameB) {
  const width = 1080;
  const height = 1920;
  const frameBytes = width * height * 4;
  var delta = 0;
  for (var y = 760; y < 1160; y++) {
    final startA = frameA * frameBytes + (y * width + 340) * 4;
    final startB = frameB * frameBytes + (y * width + 340) * 4;
    for (var x = 0; x < 400; x++) {
      final i = x * 4;
      if (frames[startA + i] != frames[startB + i] ||
          frames[startA + i + 1] != frames[startB + i + 1] ||
          frames[startA + i + 2] != frames[startB + i + 2]) {
        delta++;
      }
    }
  }
  return delta;
}

/// Paints [delegates] and returns raw RGBA of the 400×200 boundary.
Future<Uint8List> _paintLabel(
  WidgetTester tester,
  Uint8List bytes,
  LottieDelegates delegates,
) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 400,
            height: 200,
            child: Lottie.memory(bytes, animate: false, delegates: delegates),
          ),
        ),
      ),
    ),
  );
  // Parsing and the following setState are real futures. `pump` alone does not
  // flush them, and `toImage` does not complete on the fake clock.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
  if (image == null) {
    throw StateError('toImage returned null.');
  }
  final data = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  image.dispose();
  if (data == null) {
    throw StateError('Could not read the Lottie label pixels.');
  }
  return data.buffer.asUint8List();
}

/// Records the Lottie clock gap and the dynamic-text delegate.
void main() {
  testWidgets('Lottie inside Fluvie capture does not advance its own clock', (
    tester,
  ) async {
    final json = await tester.runAsync(
      () => File('assets/moving_box.json').readAsString(),
    );
    if (json == null) {
      throw StateError('Could not read moving_box.json.');
    }
    final frames = await _capture(tester, json);
    final delta = _boxDelta(frames, 0, 20);
    final painted0 = _painted(frames, 0);
    final painted20 = _painted(frames, 20);
    // ignore: avoid_print
    print(
      'phase0 lottie zero-pump painted frame0 $painted0 frame20 $painted20 '
      'box delta $delta',
    );
    expect(painted0, greaterThan(0), reason: 'the Lottie box should paint');
    expect(
      delta,
      0,
      reason: 'Fluvie capture pumps with a zero duration, so the Lottie controller stays on its first drawn frame.',
    );
    expect(painted20, painted0);
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('Lottie advances when the capture pump elapses a frame', (
    tester,
  ) async {
    final json = await tester.runAsync(
      () => File('assets/moving_box.json').readAsString(),
    );
    if (json == null) {
      throw StateError('Could not read moving_box.json.');
    }
    final frames = await _capture(
      tester,
      json,
      step: const Duration(milliseconds: 33),
    );
    final delta = _boxDelta(frames, 0, 20);
    // ignore: avoid_print
    print('phase0 lottie timed-pump box delta frame0 vs frame20: $delta');
    expect(
      delta,
      greaterThan(0),
      reason: 'A pump that elapses one frame should move the Lottie box. A zero delta means the clock gap is not only the zero-duration pump.',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('LottieDelegates.text changes the painted label', (tester) async {
    final loaded = await tester.runAsync(
      () => File('assets/label.json').readAsBytes(),
    );
    if (loaded == null) {
      throw StateError('Could not read label.json.');
    }
    final bytes = Uint8List.fromList(loaded);
    final before = await _paintLabel(
      tester,
      bytes,
      LottieDelegates(text: (value) => value),
    );
    final after = await _paintLabel(
      tester,
      bytes,
      LottieDelegates(text: (value) => value == 'BEFORE' ? 'AFTER' : value),
    );
    expect(before, isNot(equals(after)));
  });
}
