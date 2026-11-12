import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:phase1_probe/story_12.dart';

void main() {
  test('the authored story is a twelve-second 1080 by 1920 reel', () {
    final video = build();

    expect(video.width, 1080);
    expect(video.height, 1920);
    expect(video.fps, 30);
    expect(video.totalFrames, 360);
    expect(storyDurationMs, inInclusiveRange(10000, 15000));
    expect(video.totalFrames, storyDurationMs * video.fps ~/ 1000);
    expect(video.captions?.source, 'assets/transcript.srt');
    expect(video.poster, const Time.ms(coverAtMs));
    expect(video.audio, hasLength(1));
    expect(video.audio.single.isSfx, isTrue);
    expect(video.audio.single.source, 'assets/tone.wav');
    expect(video.audio.single.at, Trigger.at(const Time.ms(flashStartMs)));
  });

  test('the cover frame sits inside the first supplied cue', () {
    final transcript = File('assets/transcript.srt').readAsStringSync();

    expect(transcript, contains('00:00:02,000 --> 00:00:06,000'));
    expect(transcript, contains('A synthetic caption'));
    expect(transcript, contains('00:00:06,000 --> 00:00:11,000'));
    expect(transcript, contains('from a supplied transcript'));
    expect(coverAtMs, inInclusiveRange(2000, 5999));
    expect(coverAtMs, lessThan(storyDurationMs));
  });

  test('the scene declares the synthetic still', () {
    final images = <Image>[];
    walkSceneTree(build().scenes, (widget) {
      if (widget is Image) {
        images.add(widget);
      }
    });

    expect(images, hasLength(1));
    expect(images.single.source, const MediaSource.asset('assets/swatch.png'));
  });
}
