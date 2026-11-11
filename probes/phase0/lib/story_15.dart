import 'package:flutter/widgets.dart' hide Animation, Image;
import 'package:fluvie/fluvie.dart';

/// Fifteen-second check of a still, a scale, burned-in captions, and a tone.
///
/// The 2026-11-11 headless run used this scene from a throwaway directory,
/// with absolute paths to the generated swatch and tone. That directory was
/// not committed. This copy keeps the same scene and reads
/// `assets/swatch.png` and `assets/tone.wav`, which
/// `tool/generate_story15_assets.py` writes. Run `fluvie render` from
/// `probes/phase0` so those relative paths resolve.
Video build() {
  return Video(
    width: 1080,
    height: 1920,
    fps: 30,
    poster: const Time.seconds(0),
    audio: const [Audio.music('assets/tone.wav')],
    captions: Captions.words(const [CaptionWord('Hello', at: Time.zero)]),
    scenes: [
      Scene(
        duration: const Time.seconds(15),
        background: Background.color(const Color(0xFF224466)),
        children: [
          Image.file(
            'assets/swatch.png',
            fit: BoxFit.cover,
          ).animate([Animation.kenBurns(zoom: 1.08)]),
        ],
      ),
    ],
  );
}
