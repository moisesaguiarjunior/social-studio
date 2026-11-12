import 'package:flutter/widgets.dart' hide Animation, Image;
import 'package:fluvie/fluvie.dart';

/// Authored length of the phase 1 Story, in milliseconds.
///
/// Ten to fifteen seconds is the spike window. Twelve sits inside it and
/// inside the Sharing to Stories maximum of twenty seconds.
const int storyDurationMs = 12000;

/// When the full-frame white flash and the tone are authored to start.
const int flashStartMs = 1000;

/// How long the flash stays on screen.
const int flashDurationMs = 200;

/// Poster time, inside the first caption cue, used as the cover frame.
const int coverAtMs = 3000;

/// Twelve-second Story: a dark lead-in, a white flash with a tone, then a
/// still that scales slowly under a supplied transcript.
///
/// The still and the tone are written by `tool/generate_story_assets.py`.
/// Run a render from `probes/phase1` so `assets/` resolves.
Video build() {
  return Video(
    width: 1080,
    height: 1920,
    fps: 30,
    poster: const Time.ms(coverAtMs),
    audio: [
      Audio.sfx('assets/tone.wav', at: Trigger.at(const Time.ms(flashStartMs))),
    ],
    captions: const Captions.fromSrt(
      'assets/transcript.srt',
      style: CaptionStyle.subtitle(),
    ),
    scenes: [
      Scene(
        duration: const Time.ms(flashStartMs),
        background: Background.color(const Color(0xFF101010)),
      ),
      Scene(
        duration: const Time.ms(flashDurationMs),
        background: Background.color(const Color(0xFFFFFFFF)),
      ),
      Scene(
        duration: const Time.ms(
          storyDurationMs - flashStartMs - flashDurationMs,
        ),
        background: Background.color(const Color(0xFF224466)),
        children: [
          Image.asset(
            'assets/swatch.png',
            fit: BoxFit.cover,
          ).animate([Animation.kenBurns(zoom: 1.08)]),
        ],
      ),
    ],
  );
}
