import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phase1_probe/story_12.dart';

const int _width = 1080;
const int _height = 1920;
const int _frameBytes = _width * _height * 4;
const int _secondCueMs = 8000;
const int _stillMin = 10000;
const int _motionMin = 500;
const int _captionMin = 40;

/// Encodes the phase 1 Story on a device and reads the captured frames.
///
/// A container header is not acceptance. The frames have to contain the
/// synthetic still, a change in that still between the two cues, and
/// caption ink at both times. The tone is measured afterwards by
/// `tool/inspect_story.py` on the encoded file. This is a functional
/// check. It does not measure speed, memory, heat, or picture quality,
/// and it does not stand in for a phone.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('encodes the story with the still in the frames', (tester) async {
    final file = await tester.runAsync(() async {
      // fluvie 0.3.1's aspect render pre-resolves images and does not
      // pre-resolve captions. The CLI path does. Without this, every frame
      // throws while building CaptionsLayer and the test never keeps a file.
      final video = build();
      final captions = video.captions;
      if (captions == null) {
        throw StateError('The story declares no captions.');
      }
      final scope = resolverScope(null);
      try {
        await scope.resolver.preResolveCaptions(captions.captionSource);
        final rendered =
            await OnDeviceVideoRenderer(
              mediaResolver: scope.resolver,
              hostFactory: (size) =>
                  _ScheduleFlushingCaptureHost(OffscreenCaptureHost(size)),
            ).render(
              composition: video,
              aspect: Aspect.reels,
              duration: const Duration(milliseconds: storyDurationMs),
              fps: 30,
              longEdge: 1920,
              audio: true,
              onProgress: (progress) {
                final done = progress.completedFrames;
                final total = progress.totalFrames;
                final frames = done == null ? '' : ' $done/${total ?? '-'}';
                stdout.writeln('PHASE1_PROGRESS ${progress.phase.name}$frames');
              },
            );
        // The encode sandbox is not what a host lists, and the test
        // uninstalls the app. Copy into the platform temp directory.
        // A failed copy fails the test.
        // systemTemp is the code cache on Android. The app cache is the
        // sibling a host can read with a relative path. Both copies have
        // to succeed.
        final tempCopy = File(
          '${Directory.systemTemp.path}/phase1-story12.mp4',
        );
        final cacheCopy = File(
          '${tempCopy.parent.parent.path}/cache/phase1-story12.mp4',
        );
        await cacheCopy.parent.create(recursive: true);
        await rendered.copy(tempCopy.path);
        await rendered.copy(cacheCopy.path);
        debugPrint('PHASE1_HOST_COPY cache');
        // Leave the cache file in place while a host reads it. The test
        // uninstalls the app when this function returns.
        await Future<void>.delayed(const Duration(seconds: 15));
        return rendered;
      } finally {
        await scope.dispose();
      }
    });
    if (file == null) {
      fail('The device renderer returned no file.');
    }

    final length = file.lengthSync();
    stdout.writeln('PHASE1_FILE ${file.path}');
    stdout.writeln('PHASE1_BYTES $length');
    expect(file.existsSync(), isTrue);
    expect(length, greaterThan(1024));
    final handle = file.openSync();
    final header = handle.readSync(12);
    handle.closeSync();
    expect(header.length, greaterThanOrEqualTo(8));
    expect(String.fromCharCodes(header.sublist(4, 8)), 'ftyp');

    final frames = File('${file.parent.path}/frames.rgba');
    expect(
      frames.existsSync(),
      isTrue,
      reason: 'The capture wrote no raw frames to check.',
    );
    final atThree = _readFrame(frames, _frameIndex(coverAtMs));
    final atEight = _readFrame(frames, _frameIndex(_secondCueMs));
    final goldThree = _countWhere(atThree, _isSwatchGold);
    final goldEight = _countWhere(atEight, _isSwatchGold);
    final motion = _changedPixels(
      atThree,
      atEight,
      x0: _width ~/ 4,
      x1: (_width * 3) ~/ 4,
      y0: (_height * 3) ~/ 8,
      y1: (_height * 11) ~/ 20,
    );
    final inkThree = _countWhere(
      atThree,
      _isCaptionInk,
      y0: (_height * 3) ~/ 5,
    );
    final inkEight = _countWhere(
      atEight,
      _isCaptionInk,
      y0: (_height * 3) ~/ 5,
    );
    final captionChange = _changedPixels(
      atThree,
      atEight,
      x0: 0,
      x1: _width,
      y0: (_height * 3) ~/ 5,
      y1: _height,
    );
    debugPrint('PHASE1_STILL_3S $goldThree');
    debugPrint('PHASE1_STILL_8S $goldEight');
    debugPrint('PHASE1_MOTION $motion');
    debugPrint('PHASE1_CAPTION_3S $inkThree');
    debugPrint('PHASE1_CAPTION_8S $inkEight');
    debugPrint('PHASE1_CAPTION_CHANGE $captionChange');
    expect(
      goldThree,
      greaterThanOrEqualTo(_stillMin),
      reason: 'The frame at 3s does not contain the synthetic still.',
    );
    expect(
      goldEight,
      greaterThanOrEqualTo(_stillMin),
      reason: 'The frame at 8s does not contain the synthetic still.',
    );
    expect(
      motion,
      greaterThanOrEqualTo(_motionMin),
      reason: 'The still does not change between the two cues.',
    );
    expect(inkThree, greaterThanOrEqualTo(_captionMin));
    expect(inkEight, greaterThanOrEqualTo(_captionMin));
    expect(
      captionChange,
      greaterThanOrEqualTo(_captionMin),
      reason: 'The two cues paint the same caption band.',
    );
  }, timeout: const Timeout(Duration(minutes: 30)));
}

int _frameIndex(int timeMs) => timeMs * 30 ~/ 1000;

Uint8List _readFrame(File frames, int index) {
  final handle = frames.openSync();
  try {
    handle.setPositionSync(index * _frameBytes);
    final bytes = handle.readSync(_frameBytes);
    if (bytes.length != _frameBytes) {
      fail('Frame $index was ${bytes.length} bytes.');
    }
    return Uint8List.fromList(bytes);
  } finally {
    handle.closeSync();
  }
}

bool _isSwatchGold(int red, int green, int blue) =>
    red > 180 && green > 120 && blue < 140;

bool _isCaptionInk(int red, int green, int blue) =>
    red > 220 && green > 220 && blue > 220;

int _countWhere(
  Uint8List rgba,
  bool Function(int red, int green, int blue) accept, {
  int y0 = 0,
}) {
  var count = 0;
  for (var y = y0; y < _height; y++) {
    final row = y * _width * 4;
    for (var x = 0; x < _width; x++) {
      final index = row + x * 4;
      if (accept(rgba[index], rgba[index + 1], rgba[index + 2])) {
        count += 1;
      }
    }
  }
  return count;
}

int _changedPixels(
  Uint8List left,
  Uint8List right, {
  required int x0,
  required int x1,
  required int y0,
  required int y1,
}) {
  var count = 0;
  for (var y = y0; y < y1; y++) {
    final row = y * _width * 4;
    for (var x = x0; x < x1; x++) {
      final index = row + x * 4;
      if (left[index] != right[index] ||
          left[index + 1] != right[index + 1] ||
          left[index + 2] != right[index + 2]) {
        count += 1;
      }
    }
  }
  return count;
}

/// Drains the post-frame callback fluvie uses to resolve motion.
///
/// Until that callback runs, an animated child is painted at opacity 0.
/// [OffscreenCaptureHost] builds and paints without draining it, so the
/// still never reaches the captured frames. One draw of the live test
/// binding, after mount, runs the callback. The next capture build paints
/// the resolved still. This does not change fluvie.
final class _ScheduleFlushingCaptureHost implements CaptureHost {
  _ScheduleFlushingCaptureHost(this._inner);

  final CaptureHost _inner;

  @override
  Future<void> mount(Widget tree) async {
    await _inner.mount(tree);
    _flushSchedules();
  }

  @override
  Future<void> pumpFrame() => _inner.pumpFrame();

  @override
  Future<void> dispose() => _inner.dispose();

  void _flushSchedules() {
    final binding = WidgetsBinding.instance;
    if (binding is! LiveTestWidgetsFlutterBinding) {
      throw StateError('The schedule flush needs the live test binding.');
    }
    if (binding.schedulerPhase != SchedulerPhase.idle) {
      throw StateError(
        'The schedule flush ran while the scheduler was '
        '${binding.schedulerPhase.name}.',
      );
    }
    final previous = binding.framePolicy;
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    try {
      binding.handleBeginFrame(Duration.zero);
      binding.handleDrawFrame();
    } finally {
      binding.framePolicy = previous;
    }
    debugPrint('PHASE1_SCHEDULE_FLUSH ok');
  }
}
