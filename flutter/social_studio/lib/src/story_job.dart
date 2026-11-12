import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:json_schema/json_schema.dart';
import 'package:path/path.dart' as p;

/// Invalid job data, timing or local media. No rendering has started.
final class StoryJobException implements Exception {
  /// Creates a failure with a user-readable explanation.
  const StoryJobException(this.message);

  /// The validation failure, without embedding the supplied content.
  final String message;

  @override
  String toString() => 'StoryJobException: $message';
}

/// One supplied caption interval, in milliseconds, with exclusive end time.
final class StoryCaption {
  const StoryCaption._(this.startMs, this.endMs, this.text);

  /// Inclusive start, in milliseconds.
  final int startMs;

  /// Exclusive end, in milliseconds.
  final int endMs;

  /// Supplied text; never sent for transcription or analysis.
  final String text;
}

/// One photo on the ordered Story timeline, ending with a hard cut.
final class StoryScene {
  const StoryScene._(this.imagePath, this.durationMs);

  /// Resolved local PNG/JPEG path.
  final String imagePath;

  /// Authored length in milliseconds, containing a whole number of frames.
  final int durationMs;
}

/// Validated local input for the versioned photo Story template.
///
/// Use [load] with the checkout's canonical `spec/desktop-story` directory. This API
/// supports local files only; authorization belongs to the consuming app.
final class StoryJob {
  StoryJob._({
    required this.scenes,
    required this.audioPath,
    required this.durationMs,
    required this.coverMs,
    required this.captions,
    required this.profile,
    required this.template,
    required Map<String, String> schemas,
    required Map<String, Digest> mediaHashes,
  }) : _schemas = Map.unmodifiable(schemas),
       _mediaHashes = Map.unmodifiable(mediaHashes);

  final Map<String, String> _schemas;
  final Map<String, Digest> _mediaHashes;

  /// Ordered photo scenes, including one scene for a single-image job.
  final List<StoryScene> scenes;

  /// Resolved local PCM/WAVE input path.
  final String audioPath;

  /// Authored length, in milliseconds.
  final int durationMs;

  /// Cover time, in milliseconds from the start.
  final int coverMs;

  /// Ordered, nonoverlapping caption cues.
  final List<StoryCaption> captions;

  /// Validated profile data from the canonical spec.
  final Map<String, Object?> profile;

  /// Validated template data from the canonical spec.
  final Map<String, Object?> template;

  /// Loads and validates a job before any capture or encoder process starts.
  ///
  /// Throws [StoryJobException] for schema, timing or media failures. Schemas
  /// are constructed synchronously, so remote references cannot be fetched.
  static StoryJob load(String jobPath, {required String specDirectory}) {
    final data = _object(File(jobPath).readAsStringSync());
    final spec = Directory(specDirectory);
    final schemas = {
      for (final name in ['story-job', 'story-profile', 'story-template'])
        '$name.schema.json': File(p.join(spec.path, '$name.schema.json'))
            .readAsStringSync(),
    };
    void validate(Object value, String name) {
      final source = schemas[name];
      if (source == null) throw StateError('Missing schema.');
      if (!JsonSchema.create(source).validate(value).isValid) {
        throw StoryJobException('Input does not match $name.');
      }
    }

    validate(data, 'story-job.schema.json');
    final profile = _object(
      File(p.join(spec.path, 'story-profile.json')).readAsStringSync(),
    );
    final template = _object(
      File(p.join(spec.path, 'story-template.json')).readAsStringSync(),
    );
    validate(profile, 'story-profile.schema.json');
    validate(template, 'story-template.schema.json');
    final duration = integer(data, 'durationMs');
    final cover = integer(data, 'coverMs');
    final fps = integer(profile, 'fps');
    if (duration * fps % 1000 != 0) {
      throw const StoryJobException(
        'Duration must contain a whole number of frames.',
      );
    }
    if (duration > integer(profile, 'maximumDurationMs') || cover >= duration) {
      throw const StoryJobException(
        'Duration or cover is outside the profile/job interval.',
      );
    }
    final rawCues = data['captions'];
    if (rawCues is! List<Object?>) {
      throw const StoryJobException('Expected caption cues.');
    }
    final cues = <StoryCaption>[];
    var previousEnd = 0;
    for (final rawCue in rawCues) {
      if (rawCue is! Map<String, Object?>) {
        throw const StoryJobException('Expected a caption object.');
      }
      final start = integer(rawCue, 'startMs');
      final end = integer(rawCue, 'endMs');
      final text = string(rawCue, 'text');
      if (captionFrame(end, fps) <= captionFrame(start, fps)) {
        throw const StoryJobException(
          'Each caption must occupy at least one frame.',
        );
      }
      if (start < previousEnd ||
          end <= start ||
          end > duration ||
          text.trim().isEmpty ||
          text.contains('\n') ||
          text.contains('\r') ||
          text.contains('-->')) {
        throw const StoryJobException(
          'Captions must be nonempty single lines, ordered and inside the job duration.',
        );
      }
      cues.add(StoryCaption._(start, end, text));
      previousEnd = end;
    }
    final base = p.dirname(p.absolute(jobPath));
    final rawScenes = data['scenes'];
    final List<Object?> entries;
    if (rawScenes is List<Object?>) {
      entries = rawScenes;
    } else {
      entries = [
        {'image': string(data, 'image'), 'durationMs': duration},
      ];
    }
    final scenes = <StoryScene>[];
    var sceneDuration = 0;
    for (final entry in entries) {
      if (entry is! Map<String, Object?>) {
        throw const StoryJobException('Expected a scene object.');
      }
      final length = integer(entry, 'durationMs');
      if (length * fps % 1000 != 0) {
        throw const StoryJobException(
          'Each scene must contain a whole number of frames.',
        );
      }
      final image = _localImage(string(entry, 'image'), base);
      scenes.add(StoryScene._(image, length));
      sceneDuration += length;
    }
    if (sceneDuration != duration) {
      throw const StoryJobException('Scene durations must sum to durationMs.');
    }
    final audio = _localFile(string(data, 'audio'), base);
    final signature = File(audio).openSync();
    try {
      final bytes = signature.readSync(12);
      if (bytes.length != 12 ||
          ascii.decode(bytes.sublist(0, 4), allowInvalid: true) != 'RIFF' ||
          ascii.decode(bytes.sublist(8, 12), allowInvalid: true) != 'WAVE') {
        throw const StoryJobException('Audio must be a local RIFF/WAVE file.');
      }
    } finally {
      signature.closeSync();
    }
    return StoryJob._(
      scenes: List.unmodifiable(scenes),
      audioPath: audio,
      durationMs: duration,
      coverMs: cover,
      captions: List.unmodifiable(cues),
      profile: Map.unmodifiable(profile),
      template: Map.unmodifiable(template),
      schemas: schemas,
      mediaHashes: {
        for (final path in {audio, ...scenes.map((scene) => scene.imagePath)})
          path: _mediaDigest(path),
      },
    );
  }

  /// Rejects media changed or removed since this job was validated.
  ///
  /// Hashes are streamed in bounded chunks. Call before capture and before
  /// exposing final outputs. This detects persistent changes, not a filesystem
  /// snapshot or a temporary replacement restored between checks.
  void verifyMediaUnchanged() {
    for (final entry in _mediaHashes.entries) {
      try {
        if (_mediaDigest(entry.key) == entry.value) continue;
      } on FileSystemException {
        // A removed or unreadable input is also an integrity failure.
      }
      throw const StoryJobException(
        'A source media file changed after validation; render again.',
      );
    }
  }

  /// Writes the validated job and its configuration for a capture subprocess.
  ///
  /// [directory] must be private temporary storage. Media paths are rebased
  /// relative to it; media bytes are not copied. The original job is never
  /// reopened. Returns the snapshot job path. Remove the directory after use.
  String writeSnapshot(String directory) {
    final target = Directory(p.absolute(directory))
      ..createSync(recursive: true);
    final base = target.resolveSymbolicLinksSync();
    void write(String name, Object value) =>
        File(p.join(target.path, name)).writeAsStringSync(jsonEncode(value));
    for (final schema in _schemas.entries) {
      File(p.join(target.path, schema.key)).writeAsStringSync(schema.value);
    }
    write('story-profile.json', profile);
    write('story-template.json', template);
    write('job.json', {
      'version': 1,
      'template': string(template, 'id'),
      'scenes': [
        for (final scene in scenes)
          {
            'image': p.relative(scene.imagePath, from: base),
            'durationMs': scene.durationMs,
          },
      ],
      'audio': p.relative(audioPath, from: base),
      'durationMs': durationMs,
      'coverMs': coverMs,
      'captions': [
        for (final cue in captions)
          {'startMs': cue.startMs, 'endMs': cue.endMs, 'text': cue.text},
      ],
    });
    return p.join(target.path, 'job.json');
  }

  /// Converts the supplied cues to SRT for Fluvie's existing caption parser.
  String toSrt() => [
    for (var i = 0; i < captions.length; i++)
      '${i + 1}\n${_time(captions[i].startMs)} --> ${_time(captions[i].endMs)}\n${captions[i].text}\n',
  ].join('\n');
}

/// Resolves a caption boundary with Fluvie 0.3.1's exact operation order.
///
/// IEEE-754 half boundaries can differ if multiplication/division are reordered.
/// Shared by validation and review navigation; SRT retains authored times.
int captionFrame(int milliseconds, int fps) =>
    (milliseconds / 1000 * fps).round();

Map<String, Object?> _object(String source) {
  final Object? decoded = jsonDecode(source);
  if (decoded is! Map<String, Object?>) {
    throw const StoryJobException('Expected a JSON object.');
  }
  return decoded;
}

/// Narrows a JSON integer, including an integral JSON number such as 1000.0.
int integer(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is num && value.isFinite && value == value.truncateToDouble()) {
    return value.toInt();
  }
  throw StoryJobException('Expected integer $key.');
}

/// Narrows a string at the schema-validated JSON boundary.
String string(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is String) return value;
  throw StoryJobException('Expected string $key.');
}

String _localFile(String value, String base) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      p.isAbsolute(value) ||
      value.contains('\\')) {
    throw const StoryJobException(
      'Media must use relative local paths, not URLs or absolute paths.',
    );
  }
  final file = File(p.join(base, value));
  if (!file.existsSync()) {
    throw const StoryJobException('A required local media file is missing.');
  }
  return file.resolveSymbolicLinksSync();
}

String _time(int ms) {
  String pad(int value, int width) => value.toString().padLeft(width, '0');
  return '${pad(ms ~/ 3600000, 2)}:${pad(ms ~/ 60000 % 60, 2)}:${pad(ms ~/ 1000 % 60, 2)},${pad(ms % 1000, 3)}';
}

String _localImage(String value, String base) {
  final image = _localFile(value, base);
  final imageHandle = File(image).openSync();
  try {
    final bytes = imageHandle.readSync(8);
    final png =
        bytes.length == 8 &&
        List.generate(
          8,
          (i) => bytes[i] == [137, 80, 78, 71, 13, 10, 26, 10][i],
        ).every((same) => same);
    final jpeg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    if (!png && !jpeg) {
      throw const StoryJobException('Image must be a local PNG or JPEG.');
    }
  } finally {
    imageHandle.closeSync();
  }
  return image;
}

Digest _mediaDigest(String path) {
  final output = _DigestSink();
  final input = sha256.startChunkedConversion(output);
  final file = File(path).openSync();
  try {
    while (true) {
      final bytes = file.readSync(65536);
      if (bytes.isEmpty) break;
      input.add(bytes);
    }
  } finally {
    file.closeSync();
    input.close();
  }
  final digest = output.value;
  if (digest == null) throw StateError('Media digest was not produced.');
  return digest;
}

final class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
