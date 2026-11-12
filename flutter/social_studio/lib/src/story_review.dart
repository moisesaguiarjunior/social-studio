import 'dart:convert';

import 'story_job.dart';

/// Builds a portable review page for an already rendered Story.
///
/// [template] is the checkout's `assets/review.html`. Only normalized timing,
/// dimensions and escaped caption text enter the page; input paths never do.
/// The page plays the exported MP4 and does not render the composition again.
String buildStoryReview(StoryJob job, {required String template}) {
  final fps = integer(job.profile, 'fps');
  final scenes = StringBuffer();
  var startFrame = 0;
  for (var i = 0; i < job.scenes.length; i++) {
    final scene = job.scenes[i];
    final endFrame = startFrame + scene.durationMs * fps ~/ 1000;
    scenes.write(
      '<li><button type="button" class="seek scene" '
      'data-start-frame="$startFrame" data-end-frame="$endFrame">'
      '<span class="number">${(i + 1).toString().padLeft(2, '0')}</span>'
      '<span><strong>Scene ${i + 1}</strong>'
      '<small>${_clock(startFrame * 1000 ~/ fps)} – '
      '${_clock(endFrame * 1000 ~/ fps)}</small></span>'
      '<span class="length">${_seconds(scene.durationMs)} s</span>'
      '</button></li>',
    );
    startFrame = endFrame;
  }
  const escape = HtmlEscape(HtmlEscapeMode.element);
  final captions = StringBuffer();
  for (final caption in job.captions) {
    final start = captionFrame(caption.startMs, fps);
    final end = captionFrame(caption.endMs, fps);
    captions.write(
      '<li><button type="button" class="seek cue" '
      'data-start-frame="$start" data-end-frame="$end">'
      '<time>${_clock(start * 1000 ~/ fps)}</time>'
      '<span>${escape.convert(caption.text)}</span></button></li>',
    );
  }
  final values = {
    'WIDTH': '${integer(job.profile, 'width')}',
    'HEIGHT': '${integer(job.profile, 'height')}',
    'FPS': '$fps',
    'FRAME_COUNT': '${job.durationMs * fps ~/ 1000}',
    'DURATION': _seconds(job.durationMs),
    'END_TIME': _clock(job.durationMs),
    'SCENE_COUNT': '${job.scenes.length}',
    'SCENES': scenes.toString(),
    'CAPTIONS': captions.toString(),
  };
  // One pass: supplied captions containing template-like text stay literal.
  return template.replaceAllMapped(RegExp(r'\{\{([A-Z_]+)\}\}'), (match) {
    final replacement = values[match.group(1)];
    if (replacement == null) throw StateError('Unknown review template slot.');
    return replacement;
  });
}

String _seconds(int ms) =>
    ms % 1000 == 0 ? '${ms ~/ 1000}' : (ms / 1000).toStringAsFixed(3);

String _clock(int ms) =>
    '${(ms ~/ 60000).toString().padLeft(2, '0')}:'
    '${(ms ~/ 1000 % 60).toString().padLeft(2, '0')}.'
    '${(ms % 1000).toString().padLeft(3, '0')}';
