import 'package:flutter/widgets.dart' hide Animation;
import 'package:fluvie/fluvie.dart';

/// The synthetic 1080×1920 composition behind criteria D1 and Q1.
///
/// Flat red field, one text run (`Ag Á` at 64 px), and a rectangle that
/// travels horizontally across the two seconds. No network, no photograph,
/// no recorded voice.
Video determinismVideo() {
  return Video(
    width: 1080,
    height: 1920,
    fps: 30,
    poster: const Time.seconds(0),
    scenes: [
      Scene(
        duration: const Time.seconds(2),
        background: Background.color(const Color(0xFFE23D3D)),
        children: [
          const Align(
            alignment: Alignment(0, -0.55),
            child: Text(
              'Ag Á',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 64,
                color: Color(0xFFFFFFFF),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.72),
            child:
                Container(
                  width: 160,
                  height: 160,
                  color: const Color(0xFF112233),
                ).animate([
                  Animation.fromTo(
                    const Keyframe(x: -3),
                    const Keyframe(x: 3),
                    phase: AnimationPhase.during,
                    duration: const Time.seconds(2),
                  ),
                ]),
          ),
        ],
      ),
    ],
  );
}
