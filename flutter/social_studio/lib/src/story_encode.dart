/// FFmpeg arguments for desktop Story video and cover outputs.
library;

/// Disables copied metadata on an encoded output.
///
/// Desktop video and cover commands both include this list. The video command
/// also drops chapters. A tagged input keeps location and device tags when
/// the list is omitted.
const List<String> storyDiscardedMetadataArguments = <String>[
  '-map_metadata',
  '-1',
];

/// Arguments that encode raw frames and local audio for one Story.
List<String> storyVideoArguments({
  required int width,
  required int height,
  required int fps,
  required String rawFrames,
  required String audioPath,
  required int durationMs,
  required String outputPath,
}) {
  return <String>[
    '-hide_banner',
    '-loglevel',
    'error',
    '-nostdin',
    '-f',
    'rawvideo',
    '-pixel_format',
    'rgba',
    '-video_size',
    '${width}x$height',
    '-framerate',
    '$fps',
    '-i',
    rawFrames,
    '-protocol_whitelist',
    'file,pipe',
    '-i',
    audioPath,
    '-map',
    '0:v:0',
    '-map',
    '1:a:0',
    ...storyDiscardedMetadataArguments,
    '-map_chapters',
    '-1',
    '-c:v',
    'libx264',
    '-pix_fmt',
    'yuv420p',
    '-c:a',
    'aac',
    '-af',
    'apad',
    '-t',
    '${durationMs / 1000}',
    '-movflags',
    '+faststart',
    outputPath,
  ];
}

/// Arguments that extract one cover frame from an encoded Story.
List<String> storyCoverArguments({
  required String videoPath,
  required int coverFrame,
  required String outputPath,
}) {
  return <String>[
    '-hide_banner',
    '-loglevel',
    'error',
    '-nostdin',
    '-i',
    videoPath,
    '-vf',
    'select=eq(n\\,$coverFrame)',
    '-frames:v',
    '1',
    ...storyDiscardedMetadataArguments,
    '-update',
    '1',
    outputPath,
  ];
}
