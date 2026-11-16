import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show CollectibleChildren;
import 'package:handcrafted_flutter/handcrafted_flutter.dart';

import 'story_job.dart';

/// Material decoration around declared media, retaining Fluvie pre-resolution.
///
/// [recipe] must come from schema-validated StoryJob.craft. Its values describe
/// authoring, not platform safe zones. The core package owns materials; Fluvie
/// owns media/timing. This adapter introduces neither a clock nor media loading.
final class CraftStorySurface extends StatelessWidget
    implements CollectibleChildren {
  /// Creates one fixed-canvas decoration around the declared photo subtree.
  CraftStorySurface({
    super.key,
    required this.recipe,
    required this.width,
    required this.height,
    required this.child,
  }) {
    _shape = CraftOutline.paper(
      edge: PaperEdge.values.firstWhere(
        (e) => e.name == string(recipe, 'edge'),
      ),
      edgeDepth: 3,
      edgePitch: 32,
      seed: integer(recipe, 'seed'),
    );
    _outline = _shape.pathFor(Size(width, height));
    _seam = string(recipe, 'stitch') == 'none'
        ? Path()
        : insetCraftPath(
            _outline,
            distance: craftInset(recipe, width, height) / 2,
            sampleSpacing: 2,
          );
    final length = _seam.computeMetrics().fold<double>(
      0,
      (n, m) => n + m.length,
    );
    final unit = math.min(width, height);
    // Leave room below the package's 1024-cell budget on narrow tall canvases.
    _pitch = math.max((unit * .02).clamp(4.0, 48.0), length / 800);
  }

  /// Validated authoring recipe, not arbitrary executable input.
  final Map<String, Object?> recipe;

  /// Logical canvas width.
  final double width;

  /// Logical canvas height.
  final double height;

  /// Declared media wrappers visible to Fluvie's structural collectors.
  final Widget child;
  late final CraftOutline _shape;
  late final Path _outline, _seam;
  late final double _pitch;

  @override
  Iterable<Widget> get collectibleChildren => [child];

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: CraftSurface(
      material: CraftMaterial.values.firstWhere(
        (m) => m.name == string(recipe, 'material'),
      ),
      color: craftColor(string(recipe, 'color')),
      seed: integer(recipe, 'seed'),
      scale: craftNumber(recipe, 'grainScale'),
      strength: craftNumber(recipe, 'grainStrength'),
      shape: _shape,
      child: CustomPaint(
        foregroundPainter: _CraftBorder(
          _outline,
          _seam,
          recipe,
          width < height ? width : height,
          _pitch,
        ),
        child: child,
      ),
    ),
  );
}

/// Resolves a schema-validated recipe number without an unchecked cast.
double craftNumber(Map<String, Object?> recipe, String key) {
  final value = recipe[key];
  if (value is! num || !value.isFinite) {
    throw StoryJobException('Expected finite $key.');
  }
  return value.toDouble();
}

/// Authoring margin in logical pixels, relative to the shorter canvas side.
double craftInset(Map<String, Object?> recipe, double width, double height) =>
    craftNumber(recipe, 'frameInset') * (width < height ? width : height);

/// Existing desktop color convention, shared by photo and crafted templates.
Color craftColor(String hex) {
  final digits = hex.substring(1);
  return Color(int.parse(digits.length == 6 ? 'FF$digits' : digits, radix: 16));
}

class _CraftBorder extends CustomPainter {
  const _CraftBorder(
    this.outline,
    this.seam,
    this.recipe,
    this.unit,
    this.pitch,
  );
  final Path outline, seam;
  final Map<String, Object?> recipe;
  final double unit, pitch;
  @override
  void paint(Canvas canvas, Size size) {
    final name = string(recipe, 'stitch');
    if (name == 'none') return;
    canvas.save();
    canvas.clipPath(outline);
    paintCraftStitch(
      canvas,
      seam,
      kind: CraftStitchKind.values.firstWhere((k) => k.name == name),
      thread: const Color(0xFF375366),
      width: (unit * .002).clamp(.5, 3),
      pitch: pitch,
      depth: (unit * .004).clamp(1, 12),
      compression: .5,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CraftBorder old) =>
      old.seam != seam || old.recipe != recipe;
}
