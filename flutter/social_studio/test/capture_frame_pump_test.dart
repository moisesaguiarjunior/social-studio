import 'dart:io';

import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:flutter/widgets.dart' hide Animation, Image, Tween;
import 'package:flutter_test/flutter_test.dart';

import '../tool/capture_frame_pump.dart';

void main() {
  test('invalid frame rates fail before pumping', () {
    for (final fps in [0, -1]) {
      expect(
        () => captureFramePump(fps: fps, pump: (_) async {}),
        throwsArgumentError,
      );
    }
  });

  for (final fps in [24, 29, 30, 59, 60]) {
    test('$fps fps starts at zero without accumulated rounding', () async {
      var elapsed = Duration.zero;
      final pump = captureFramePump(
        fps: fps,
        pump: (delta) async => elapsed += delta,
      );
      for (var frame = 0; frame <= fps * 120; frame++) {
        await pump();
        expect(
          elapsed.inMicroseconds,
          (frame * Duration.microsecondsPerSecond + fps ~/ 2) ~/ fps,
          reason: 'frame $frame',
        );
      }
    });
  }

  testWidgets('the capture host advances a native ticker at exact 29fps', (
    tester,
  ) async {
    final output = Directory.systemTemp.createTempSync('native-capture-');
    addTearDown(() => output.deleteSync(recursive: true));
    addTearDown(tester.view.reset);
    final video = Video(
      width: 4,
      height: 4,
      fps: 29,
      scenes: [
        Scene(
          duration: const Time.frames(30),
          children: const [_NativeClock()],
        ),
      ],
    );
    final manifest = await renderVideo(
      video: video,
      outDir: output,
      cacheEnabled: false,
      pumpWidget: tester.pumpWidget,
      pumpFrame: captureFramePump(fps: video.fps, pump: tester.pump),
      runAsync: tester.runAsync,
      setViewSize: (width, height) {
        tester.view.physicalSize = Size(width.toDouble(), height.toDouble());
        tester.view.devicePixelRatio = 1;
      },
    );
    final bytes = File('${output.path}/${manifest.framesFileName}')
        .readAsBytesSync();
    const stride = 4 * 4 * 4;
    expect(manifest.frameCount, 30);
    expect(bytes.length, 30 * stride);
    for (var frame = 0; frame < 30; frame++) {
      final offset = frame * stride;
      final elapsed =
          bytes[offset] << 16 | bytes[offset + 1] << 8 | bytes[offset + 2];
      expect(elapsed, (frame * 1000000 + 14) ~/ 29, reason: 'frame $frame');
    }
  });
}

class _NativeClock extends StatefulWidget {
  const _NativeClock();

  @override
  State<_NativeClock> createState() => _NativeClockState();
}

class _NativeClockState extends State<_NativeClock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => SizedBox.expand(
      child: ColoredBox(
        color: Color(
          0xFF000000 | (_controller.lastElapsedDuration?.inMicroseconds ?? 0),
        ),
      ),
    ),
  );
}
