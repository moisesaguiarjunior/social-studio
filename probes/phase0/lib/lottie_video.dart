import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart' hide Animation;
import 'package:fluvie/fluvie.dart';
import 'package:lottie/lottie.dart';

/// A one-second Fluvie scene whose only motion is a Lottie composition.
///
/// [compositionJson] is the synthetic moving-box file. Fluvie does not drive
/// that child; the Lottie player uses its own animation controller. The probe
/// compares two captured frames to see whether that controller advances when
/// Fluvie steps its own frame clock.
Video lottieVideo(String compositionJson) {
  return Video(
    width: 1080,
    height: 1920,
    fps: 30,
    scenes: [
      Scene(
        duration: const Time.seconds(1),
        background: Background.color(const Color(0xFFE23D3D)),
        children: [
          Center(
            child: SizedBox(
              width: 400,
              height: 400,
              child: Lottie.memory(
                Uint8List.fromList(utf8.encode(compositionJson)),
                animate: true,
                repeat: false,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
