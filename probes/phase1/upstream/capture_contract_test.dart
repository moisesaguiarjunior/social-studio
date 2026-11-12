import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

void main() {
  final binding = _CaptureOnlyBinding();

  test('offscreen motion resolves without application frames', () async {
    expect(binding, isNot(isA<TestWidgetsFlutterBinding>()));
    var applicationCallbacks = 0;
    binding.addPostFrameCallback((_) => applicationCallbacks++);
    final first = await _capture(motion: true);
    final second = await _capture(motion: true);
    expect(first, second);
    expect(applicationCallbacks, 0);
    final frameBytes = 96 * 96 * 4;
    final beginning = first.sublist(0, frameBytes);
    final ending = first.sublist(29 * frameBytes, 30 * frameBytes);
    expect(
      _goldPixels(beginning),
      greaterThan(100),
      reason: 'The animated child must be visible in captured frame zero.',
    );
    expect(beginning, isNot(ending), reason: 'The captured child must move.');
  });

  test(
    'aspect capture prepares captions without caller pre-resolution',
    () async {
      final bytes = await _capture(motion: false, captions: true);
      expect(
        _whitePixels(bytes),
        greaterThan(10),
        reason: 'Caption ink must reach the encoded-input frames.',
      );
    },
  );
  test('application frames do not alter capture or lose app state', () async {
    final appKey = GlobalKey<_ApplicationCounterState>();
    runApp(_ApplicationCounter(key: appKey));
    await Future<void>.delayed(Duration.zero);
    var appFrames = 0;
    void drawApplication() {
      binding.handleBeginFrame(Duration(milliseconds: appFrames * 16));
      binding.handleDrawFrame();
      appFrames++;
    }

    drawApplication();
    try {
      final state = appKey.currentState;
      if (state == null) throw StateError('Application did not mount.');
      var callbacks = 0;
      Future<void> advanceApplication() async {
        state.increment();
        binding.addPostFrameCallback((_) => callbacks++);
        drawApplication();
      }

      final first = await _capture(
        motion: true,
        beforeFrame: advanceApplication,
      );
      final second = await _capture(
        motion: true,
        beforeFrame: advanceApplication,
      );
      expect(first, second);
      expect(callbacks, 60);
      expect(state.value, 60);
      expect(state.lastBuiltValue, 60);
      expect(appKey.currentState, same(state));
      expect(state.mounted, isTrue);
      expect(_goldPixels(first), greaterThan(100));
    } finally {
      runApp(const SizedBox.shrink());
      await Future<void>.delayed(Duration.zero);
      drawApplication();
    }
  });

  test(
    'capture failure unmounts the boundary and allows another job',
    () async {
      final failure = _FailingCapture();
      await expectLater(
        _capture(motion: true, capture: failure),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'synthetic capture failure',
          ),
        ),
      );
      expect(failure.boundary, isNotNull);
      expect(failure.boundary?.currentContext, isNull);
      expect(_goldPixels(await _capture(motion: true)), greaterThan(100));
    },
  );

  test('disposing the offscreen host unmounts its tree', () async {
    final key = GlobalKey();
    final host = OffscreenCaptureHost(const Size(96, 96));
    await host.mount(SizedBox(key: key));
    expect(key.currentContext, isNotNull);
    await host.dispose();
    expect(key.currentContext, isNull);
    await host.dispose();
  });
}

Future<Uint8List> _capture({
  required bool motion,
  bool captions = false,
  Future<void> Function()? beforeFrame,
  FrameCaptureService capture = const RepaintBoundaryCaptureService(),
}) async {
  final directory = await Directory.systemTemp.createTemp('capture-contract-');
  final host = OffscreenCaptureHost(const Size(96, 96));
  final scope = resolverScope(null);
  final child = Container(
    width: 20,
    height: 20,
    color: const Color(0xFFF2C14E),
  );
  final video = Video(
    width: 96,
    height: 96,
    captions: captions
        ? Captions.words(
            const [CaptionWord('A', at: Time.zero)],
            style: const CaptionStyle.subtitle(),
            position: const CaptionPosition.center(),
          )
        : null,
    scenes: [
      Scene(
        duration: const Time.seconds(1),
        background: Background.color(const Color(0xFF101010)),
        children: [
          Center(
            child: motion
                ? child.animate([
                    Animation.fromTo(
                      const Keyframe(x: -1),
                      const Keyframe(x: 1),
                      phase: AnimationPhase.during,
                      duration: const Time.seconds(1),
                    ),
                  ])
                : child,
          ),
        ],
      ),
    ],
  );
  try {
    final result = await render(
      composition: Directionality(
        textDirection: TextDirection.ltr,
        child: video,
      ),
      aspect: Aspect.square,
      frameCount: 30,
      outDir: directory,
      service: RenderService(capture: capture),
      pumpWidget: host.mount,
      pumpFrame: () async {
        await beforeFrame?.call();
        await host.pumpFrame();
      },
      longEdge: 96,
      resolver: scope.resolver,
    );
    return await File('${directory.path}/${result.manifest.framesFileName}')
        .readAsBytes();
  } finally {
    await host.dispose();
    await scope.dispose();
    await directory.delete(recursive: true);
  }
}

int _goldPixels(Uint8List rgba) {
  var count = 0;
  for (var i = 0; i < rgba.length; i += 4) {
    if (rgba[i] > 180 && rgba[i + 1] > 120 && rgba[i + 2] < 140) count++;
  }
  return count;
}

int _whitePixels(Uint8List rgba) {
  var count = 0;
  for (var i = 0; i < rgba.length; i += 4) {
    if (rgba[i] > 220 && rgba[i + 1] > 220 && rgba[i + 2] > 220) count++;
  }
  return count;
}

// Ordinary production binding with application-frame scheduling disabled. The
// offscreen pipeline must not depend on unrelated engine/UI frames advancing.
class _CaptureOnlyBinding extends WidgetsFlutterBinding {
  @override
  void scheduleFrame() {}

  @override
  void scheduleWarmUpFrame() {}
}

class _FailingCapture implements FrameCaptureService {
  GlobalKey? boundary;

  @override
  Future<RawFrame> capture({
    required GlobalKey boundaryKey,
    required int frameIndex,
    required int width,
    required int height,
  }) async {
    boundary = boundaryKey;
    if (frameIndex == 1) throw StateError('synthetic capture failure');
    return const RepaintBoundaryCaptureService().capture(
      boundaryKey: boundaryKey,
      frameIndex: frameIndex,
      width: width,
      height: height,
    );
  }
}

class _ApplicationCounter extends StatefulWidget {
  const _ApplicationCounter({super.key});

  @override
  State<_ApplicationCounter> createState() => _ApplicationCounterState();
}

class _ApplicationCounterState extends State<_ApplicationCounter> {
  int value = 0;
  int lastBuiltValue = -1;

  void increment() => setState(() => value++);

  @override
  Widget build(BuildContext context) {
    lastBuiltValue = value;
    return ColoredBox(
      color: value.isEven ? const Color(0xFF00FF00) : const Color(0xFF0000FF),
    );
  }
}
