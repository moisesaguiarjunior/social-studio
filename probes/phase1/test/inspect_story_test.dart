import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Runs the phase 1 inspector.
///
/// [environment] replaces the parent environment so a developer's
/// `FLUVIE_FFMPEG` cannot turn a missing-tool check into a pass.
Future<ProcessResult> _inspect({
  required String python,
  required List<String> args,
  required Map<String, String> environment,
}) {
  return Process.run(
    python,
    ['tool/inspect_story.py', ...args],
    environment: environment,
    includeParentEnvironment: false,
  );
}

void main() {
  late String python;

  setUpAll(() async {
    final resolved = await Process.run('python3', [
      '-c',
      'import sys; print(sys.executable)',
    ]);
    python = (resolved.stdout as String).trim();
    if (resolved.exitCode != 0 || python.isEmpty) {
      fail('python3 is required for the inspector controls.');
    }
  });

  test('the parser self-check passes', () async {
    final result = await _inspect(
      python: python,
      args: const ['--self-check'],
      environment: const {},
    );

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('self-check ok'));
  });

  test('a run that cannot measure sync fails', () async {
    final directory = await Directory.systemTemp.createTemp('phase1-inspect-');
    addTearDown(() async {
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    });
    final sample = File('${directory.path}/sample.bin');
    await sample.writeAsBytes([
      0,
      0,
      0,
      8,
      0x6d,
      0x6f,
      0x6f,
      0x76,
      0,
      0,
      0,
      8,
      0x6d,
      0x64,
      0x61,
      0x74,
    ]);

    final result = await _inspect(
      python: python,
      args: [sample.path],
      environment: {'PATH': directory.path},
    );

    expect(result.exitCode, 1);
    expect(result.stdout, contains('ffprobe unavailable'));
    expect(result.stdout, contains('ffmpeg unavailable'));
    expect(result.stdout, contains('av_offset_ms not_measured'));
  });

  test('real ffmpeg reports the audio frame, not a 20 ms window', () async {
    final ffmpeg = await _ffmpeg();
    final directory = await Directory.systemTemp.createTemp('phase1-tone-');
    addTearDown(() async {
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    });
    final tone = File('${directory.path}/tone.wav');
    _writeTone(tone);

    final result = await _inspect(
      python: python,
      args: ['--audio', tone.path],
      environment: {
        'PATH': Platform.environment['PATH'] ?? '',
        'FLUVIE_FFMPEG': ffmpeg,
      },
    );

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, isNot(contains('audio_window_ms')));
    final frame = double.parse(
      _field(result.stdout as String, 'audio_frame_ms'),
    );
    final toneStart = int.parse(
      _field(result.stdout as String, 'tone_start_ms'),
    );
    final measured = await _audioFrameMs(ffmpeg, tone);
    expect(frame, closeTo(measured, 0.01));
    expect(frame, isNot(closeTo(20, 0.01)));
    expect((toneStart - 1000).abs(), lessThan(frame.ceil()));
    expect(_field(result.stdout as String, 'audio_sample_rate'), '44100');
    expect(_field(result.stdout as String, 'audio_channels'), '1');
  });

  test(
    'a decoded gold frame counts the swatch and a blue frame does not',
    () async {
      final ffmpeg = await _ffmpeg();
      final directory = await Directory.systemTemp.createTemp('phase1-still-');
      addTearDown(() async {
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      });
      final gold = File('${directory.path}/gold.mp4');
      final blue = File('${directory.path}/blue.mp4');
      await _solid(ffmpeg, '0xF2C14E', gold);
      await _solid(ffmpeg, '0x224466', blue);

      final goldResult = await _inspect(
        python: python,
        args: ['--sentinel-at', gold.path, '0'],
        environment: {
          'PATH': Platform.environment['PATH'] ?? '',
          'FLUVIE_FFMPEG': ffmpeg,
        },
      );
      final blueResult = await _inspect(
        python: python,
        args: ['--sentinel-at', blue.path, '0'],
        environment: {
          'PATH': Platform.environment['PATH'] ?? '',
          'FLUVIE_FFMPEG': ffmpeg,
        },
      );

      expect(goldResult.exitCode, 0, reason: '${goldResult.stderr}');
      expect(blueResult.exitCode, 0, reason: '${blueResult.stderr}');
      expect(
        int.parse(_field(goldResult.stdout as String, 'sentinel_pixels')),
        16 * 16,
      );
      expect(_field(blueResult.stdout as String, 'sentinel_pixels'), '0');
    },
  );

  test('a clip the blue limit rejects fails story_pixels', () async {
    final ffmpeg = await _ffmpeg();
    final directory = await Directory.systemTemp.createTemp('phase1-pixels-');
    addTearDown(() async {
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    });
    final clip = File('${directory.path}/blue-limit.mp4');
    await _writeStoryClip(ffmpeg, clip, swatch: false, captions: true);

    final result = await _inspect(
      python: python,
      args: [clip.path],
      environment: _toolEnv(ffmpeg),
    );

    expect(result.exitCode, 1, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stderr, contains('story_pixels fail'));
    expect(result.stdout, isNot(contains('story_pixels ok')));
    expect(_field(result.stdout as String, 'still_pixels_3s'), '0');
    expect(_field(result.stdout as String, 'still_pixels_8s'), '0');
    expect(
      int.parse(_field(result.stdout as String, 'caption_ink_3s')),
      greaterThanOrEqualTo(20),
    );
    expect(
      int.parse(_field(result.stdout as String, 'center_changed_pixels')),
      greaterThanOrEqualTo(100),
    );
  });

  test('a clip without caption ink fails story_pixels', () async {
    final ffmpeg = await _ffmpeg();
    final directory = await Directory.systemTemp.createTemp('phase1-pixels-');
    addTearDown(() async {
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    });
    final clip = File('${directory.path}/no-captions.mp4');
    await _writeStoryClip(ffmpeg, clip, swatch: true, captions: false);

    final result = await _inspect(
      python: python,
      args: [clip.path],
      environment: _toolEnv(ffmpeg),
    );

    expect(result.exitCode, 1, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stderr, contains('story_pixels fail'));
    expect(result.stdout, isNot(contains('story_pixels ok')));
    expect(_field(result.stdout as String, 'caption_ink_3s'), '0');
    expect(_field(result.stdout as String, 'caption_ink_8s'), '0');
    expect(
      int.parse(_field(result.stdout as String, 'still_pixels_3s')),
      greaterThanOrEqualTo(1000),
    );
    expect(
      int.parse(_field(result.stdout as String, 'center_changed_pixels')),
      greaterThanOrEqualTo(100),
    );
  });

  test('a clip with caption ink only at three seconds fails', () async {
    final ffmpeg = await _ffmpeg();
    final directory = await Directory.systemTemp.createTemp('phase1-pixels-');
    addTearDown(() async {
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    });
    final clip = File('${directory.path}/caption-once.mp4');
    await _writeStoryClip(
      ffmpeg,
      clip,
      swatch: true,
      captions: true,
      captionAtEightSeconds: false,
    );

    final result = await _inspect(
      python: python,
      args: [clip.path],
      environment: _toolEnv(ffmpeg),
    );

    expect(result.exitCode, 1, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stderr, contains('story_pixels fail'));
    expect(result.stdout, isNot(contains('story_pixels ok')));
    expect(
      int.parse(_field(result.stdout as String, 'caption_ink_3s')),
      greaterThanOrEqualTo(20),
    );
    expect(_field(result.stdout as String, 'caption_ink_8s'), '0');
    expect(
      int.parse(_field(result.stdout as String, 'still_pixels_3s')),
      greaterThanOrEqualTo(1000),
    );
    expect(
      int.parse(_field(result.stdout as String, 'still_pixels_8s')),
      greaterThanOrEqualTo(1000),
    );
    expect(
      int.parse(_field(result.stdout as String, 'center_changed_pixels')),
      greaterThanOrEqualTo(100),
    );
    expect(
      int.parse(_field(result.stdout as String, 'caption_changed_pixels')),
      greaterThanOrEqualTo(20),
    );
  });

  test('a clip with a frozen swatch fails story_pixels', () async {
    final ffmpeg = await _ffmpeg();
    final directory = await Directory.systemTemp.createTemp('phase1-pixels-');
    addTearDown(() async {
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    });
    final clip = File('${directory.path}/frozen.mp4');
    await _writeStoryClip(
      ffmpeg,
      clip,
      swatch: true,
      captions: true,
      motion: false,
    );

    final result = await _inspect(
      python: python,
      args: [clip.path],
      environment: _toolEnv(ffmpeg),
    );

    expect(result.exitCode, 1, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stderr, contains('story_pixels fail'));
    expect(result.stdout, isNot(contains('story_pixels ok')));
    expect(_field(result.stdout as String, 'center_changed_pixels'), '0');
    expect(
      int.parse(_field(result.stdout as String, 'still_pixels_3s')),
      greaterThanOrEqualTo(1000),
    );
    expect(
      int.parse(_field(result.stdout as String, 'still_pixels_8s')),
      greaterThanOrEqualTo(1000),
    );
    for (final label in ['caption_ink_3s', 'caption_ink_8s']) {
      expect(
        int.parse(_field(result.stdout as String, label)),
        greaterThanOrEqualTo(20),
      );
    }
    expect(
      int.parse(_field(result.stdout as String, 'caption_changed_pixels')),
      greaterThanOrEqualTo(20),
    );
  });

  test('a clip with the swatch, motion, and captions passes', () async {
    final ffmpeg = await _ffmpeg();
    final directory = await Directory.systemTemp.createTemp('phase1-pixels-');
    addTearDown(() async {
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    });
    final clip = File('${directory.path}/pass.mp4');
    await _writeStoryClip(ffmpeg, clip, swatch: true, captions: true);

    final result = await _inspect(
      python: python,
      args: [clip.path],
      environment: _toolEnv(ffmpeg),
    );

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('story_pixels ok'));
    expect(result.stderr, isNot(contains('story_pixels fail')));
    for (final label in ['still_pixels_3s', 'still_pixels_8s']) {
      expect(
        int.parse(_field(result.stdout as String, label)),
        greaterThanOrEqualTo(1000),
      );
    }
    for (final label in ['caption_ink_3s', 'caption_ink_8s']) {
      expect(
        int.parse(_field(result.stdout as String, label)),
        greaterThanOrEqualTo(20),
      );
    }
    expect(
      int.parse(_field(result.stdout as String, 'center_changed_pixels')),
      greaterThanOrEqualTo(100),
    );
    expect(
      int.parse(_field(result.stdout as String, 'caption_changed_pixels')),
      greaterThanOrEqualTo(20),
    );
  });
}

Future<double> _audioFrameMs(String ffmpeg, File tone) async {
  final probe = await Process.run(ffmpeg, [
    '-hide_banner',
    '-i',
    tone.path,
    '-vn',
    '-af',
    'astats=metadata=1:reset=1:length=0.02,ametadata=print',
    '-f',
    'null',
    '-',
  ]);
  final times = <double>[];
  for (final line in (probe.stderr as String).split('\n')) {
    final marker = line.lastIndexOf('] ');
    final body = (marker == -1 ? line : line.substring(marker + 2)).trim();
    if (!body.startsWith('frame:')) {
      continue;
    }
    for (final part in body.split(RegExp(r'\s+'))) {
      if (part.startsWith('pts_time:')) {
        times.add(double.parse(part.split(':')[1]));
      }
    }
  }
  if (times.length < 2) {
    fail('ffmpeg did not print two audio frames.');
  }
  return (times[1] - times[0]) * 1000;
}

Map<String, String> _toolEnv(String ffmpeg) => {
  'PATH': Platform.environment['PATH'] ?? '',
  'FLUVIE_FFMPEG': ffmpeg,
};

Future<String> _ffmpeg() async {
  final configured = Platform.environment['FLUVIE_FFMPEG'];
  if (configured != null &&
      configured.isNotEmpty &&
      File(configured).existsSync()) {
    return configured;
  }
  final which = await Process.run('which', ['ffmpeg']);
  final found = (which.stdout as String).trim();
  if (which.exitCode != 0 || found.isEmpty) {
    fail('ffmpeg is required to measure a real audio frame.');
  }
  return found;
}

String _field(String stdout, String name) {
  for (final line in stdout.split('\n')) {
    if (line.startsWith('$name ')) {
      return line.substring(name.length + 1).trim();
    }
  }
  fail('Missing $name in:\n$stdout');
}

void _writeTone(File file) {
  const rate = 44100;
  const seconds = 2;
  final samples = BytesBuilder();
  for (var i = 0; i < rate * seconds; i++) {
    final amplitude = i >= rate ? 0.2 : 0.0;
    final value = (amplitude * 32767 * math.sin(2 * math.pi * 440 * i / rate))
        .round();
    samples
      ..addByte(value & 0xff)
      ..addByte((value >> 8) & 0xff);
  }
  final data = samples.toBytes();
  final header = BytesBuilder()
    ..add('RIFF'.codeUnits)
    ..add(_le32(36 + data.length))
    ..add('WAVE'.codeUnits)
    ..add('fmt '.codeUnits)
    ..add(_le32(16))
    ..add(_le16(1))
    ..add(_le16(1))
    ..add(_le32(rate))
    ..add(_le32(rate * 2))
    ..add(_le16(2))
    ..add(_le16(16))
    ..add('data'.codeUnits)
    ..add(_le32(data.length))
    ..add(data);
  file.writeAsBytesSync(header.toBytes());
}

List<int> _le16(int value) => [value & 0xff, (value >> 8) & 0xff];

List<int> _le32(int value) => [
  value & 0xff,
  (value >> 8) & 0xff,
  (value >> 16) & 0xff,
  (value >> 24) & 0xff,
];

/// Nine-second 64×64 clip with a dark lead-in, a white flash, and a tone.
///
/// [swatch] false fills with red 242, green 193, blue 200. That color passes
/// `r>180` and `g>120` and fails only `b<140`. [captions] false leaves the
/// lower band without near-white pixels. [captionAtEightSeconds] false keeps
/// that ink at three seconds and drops it at eight, while the caption band
/// still changes. [motion] false leaves the swatch block in one place.
/// The block stays in the center band the inspector uses for motion.
Future<void> _writeStoryClip(
  String ffmpeg,
  File output, {
  required bool swatch,
  required bool captions,
  bool captionAtEightSeconds = true,
  bool motion = true,
}) async {
  const width = 64;
  const height = 64;
  const fps = 30;
  const frameCount = 9 * fps;
  final fill = swatch
      ? (red: 242, green: 193, blue: 78)
      : (red: 242, green: 193, blue: 200);
  final raw = BytesBuilder(copy: false);
  for (var frame = 0; frame < frameCount; frame++) {
    late ({int red, int green, int blue}) color;
    if (frame < 6) {
      color = (red: 16, green: 16, blue: 16);
    } else if (frame < 12) {
      color = (red: 255, green: 255, blue: 255);
    } else {
      color = fill;
    }
    final pixels = Uint8List(width * height * 3);
    for (var index = 0; index < pixels.length; index += 3) {
      pixels[index] = color.red;
      pixels[index + 1] = color.green;
      pixels[index + 2] = color.blue;
    }
    if (frame >= 12) {
      final later = frame >= 150;
      _fillRect(
        pixels,
        width,
        x: motion && later ? 32 : 16,
        y: 24,
        rectWidth: 10,
        rectHeight: 10,
        red: 58,
        green: 124,
        blue: 165,
      );
      if (captions && (captionAtEightSeconds || !later)) {
        _fillRect(
          pixels,
          width,
          x: later ? 40 : 4,
          y: 50,
          rectWidth: 8,
          rectHeight: 4,
          red: 255,
          green: 255,
          blue: 255,
        );
      }
    }
    raw.add(pixels);
  }
  final rgb = File('${output.parent.path}/frames.rgb');
  await rgb.writeAsBytes(raw.toBytes(), flush: true);
  final result = await Process.run(ffmpeg, [
    '-y',
    '-hide_banner',
    '-loglevel',
    'error',
    '-f',
    'rawvideo',
    '-pix_fmt',
    'rgb24',
    '-s',
    '${width}x$height',
    '-r',
    '$fps',
    '-i',
    rgb.path,
    '-f',
    'lavfi',
    '-i',
    'sine=frequency=440:sample_rate=44100:duration=9',
    '-map',
    '0:v:0',
    '-map',
    '1:a:0',
    '-c:v',
    'png',
    '-c:a',
    'aac',
    '-shortest',
    output.path,
  ]);
  if (result.exitCode != 0) {
    fail('ffmpeg could not write ${output.path}: ${result.stderr}');
  }
}

void _fillRect(
  Uint8List pixels,
  int width, {
  required int x,
  required int y,
  required int rectWidth,
  required int rectHeight,
  required int red,
  required int green,
  required int blue,
}) {
  for (var row = y; row < y + rectHeight; row++) {
    for (var column = x; column < x + rectWidth; column++) {
      final index = (row * width + column) * 3;
      pixels[index] = red;
      pixels[index + 1] = green;
      pixels[index + 2] = blue;
    }
  }
}

Future<void> _solid(String ffmpeg, String color, File output) async {
  final result = await Process.run(ffmpeg, [
    '-y',
    '-hide_banner',
    '-loglevel',
    'error',
    '-f',
    'lavfi',
    '-i',
    'color=c=$color:s=16x16:r=1:d=1',
    '-frames:v',
    '1',
    '-c:v',
    'png',
    output.path,
  ]);
  if (result.exitCode != 0) {
    fail('ffmpeg could not write ${output.path}: ${result.stderr}');
  }
}
