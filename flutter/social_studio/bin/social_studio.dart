import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:social_studio/src/render_processes.dart';
import 'package:social_studio/src/story_encode.dart';
import 'package:social_studio/src/story_job.dart';
import 'package:social_studio/src/story_review.dart';

Future<void> main(List<String> args) async {
  RenderProcesses? processes;
  try {
    if (args.length < 2 || !{'validate', 'render'}.contains(args.first)) {
      stderr.writeln(
        'Usage: dart run bin/social_studio.dart validate JOB.json\n'
        '       dart run bin/social_studio.dart render JOB.json OUTPUT_DIRECTORY',
      );
      exitCode = 64;
      return;
    }
    final package = Directory(
      p.dirname(p.dirname(Platform.script.toFilePath())),
    );
    final spec = p.normalize(p.join(package.path, '../../spec/desktop-story'));
    final jobPath = p.absolute(args[1]);
    final job = StoryJob.load(jobPath, specDirectory: spec);
    if (args.first == 'validate') {
      if (args.length != 2) {
        throw const StoryJobException('Unexpected validation arguments.');
      }
      stdout.writeln('Valid Story job.');
      return;
    }
    if (args.length != 3) {
      throw const StoryJobException('Render requires one output directory.');
    }
    final review = buildStoryReview(
      job,
      template: await File(p.join(package.path, 'assets/review.html'))
          .readAsString(),
    );
    final destination = Directory(p.absolute(args[2]));
    if (FileSystemEntity.typeSync(destination.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const StoryJobException(
        'Output already exists; choose a new directory.',
      );
    }
    final runner = RenderProcesses(
      launcherPath: p.join(package.path, 'tool/run_process.py'),
    );
    processes = runner;
    final ffmpeg = Platform.environment['FLUVIE_FFMPEG'] ?? 'ffmpeg';
    await runner.run(ffmpeg, ['-version']);
    await destination.parent.create(recursive: true);
    final staging = await destination.parent.createTemp('.social-studio-');
    Directory? frames;
    try {
      frames = await Directory.systemTemp.createTemp('social-studio-frames-');
      job.verifyMediaUnchanged();
      final workerEnvironment = <String, String>{
        'TMPDIR': frames.path,
        'TMP': frames.path,
        'TEMP': frames.path,
      };
      final snapshotDirectory = p.join(frames.path, 'snapshot');
      final snapshotJob = job.writeSnapshot(snapshotDirectory);
      await runner.run(
        'flutter',
        [
          'test',
          '--no-pub',
          'tool/capture_story.dart',
          '--reporter',
          'expanded',
        ],
        cwd: package.path,
        environment: {
          ...workerEnvironment,
          'FLUTTER_SUPPRESS_ANALYTICS': 'true',
          'SOCIAL_STUDIO_JOB': snapshotJob,
          'SOCIAL_STUDIO_SPEC': snapshotDirectory,
          'SOCIAL_STUDIO_FONT': p.normalize(
            p.join(spec, '../../probes/phase0/assets/Roboto-Regular.ttf'),
          ),
          'SOCIAL_STUDIO_FRAMES': frames.path,
        },
      );
      final width = integer(job.profile, 'width');
      final height = integer(job.profile, 'height');
      final fps = integer(job.profile, 'fps');
      final raw = p.join(frames.path, 'frames.rgba');
      final expected = width * height * 4 * (job.durationMs * fps ~/ 1000);
      if (await File(raw).length() != expected) {
        throw StateError('Capture frame count does not match the job.');
      }
      final videoPath = p.join(staging.path, 'story.mp4');
      await runner.run(
        ffmpeg,
        storyVideoArguments(
          width: width,
          height: height,
          fps: fps,
          rawFrames: raw,
          audioPath: job.audioPath,
          durationMs: job.durationMs,
          outputPath: videoPath,
        ),
        environment: workerEnvironment,
      );
      final coverFrame = job.coverMs * fps ~/ 1000;
      await runner.run(
        ffmpeg,
        storyCoverArguments(
          videoPath: videoPath,
          coverFrame: coverFrame,
          outputPath: p.join(staging.path, 'cover.png'),
        ),
        environment: workerEnvironment,
      );
      if (!File(p.join(staging.path, 'cover.png')).existsSync()) {
        throw StateError('No cover frame produced.');
      }
      await File(p.join(staging.path, 'captions.srt'))
          .writeAsString(job.toSrt());
      await File(p.join(staging.path, 'review.html')).writeAsString(review);
      await File(p.join(staging.path, 'result.json')).writeAsString(
        '${jsonEncode({'version': 1, 'video': 'story.mp4', 'cover': 'cover.png', 'captions': 'captions.srt', 'review': 'review.html', 'width': width, 'height': height, 'fps': fps, 'durationMs': job.durationMs})}\n',
      );
      // A failed render never exposes a partial final directory.
      if (destination.existsSync()) {
        throw const StoryJobException('Output appeared during render.');
      }
      job.verifyMediaUnchanged();
      // Give interrupts queued during synchronous integrity hashing a turn
      // before committing the completed export.
      await Future<void>.delayed(Duration.zero);
      runner.throwIfCancelled();
      await staging.rename(destination.path);
      stdout.writeln(
        'Rendered story.mp4 and cover.png. Open review.html to review.',
      );
    } finally {
      try {
        if (staging.existsSync()) await staging.delete(recursive: true);
      } finally {
        if (frames != null) await frames.delete(recursive: true);
      }
    }
  } on RenderCancelledException catch (error) {
    stderr.writeln(error);
    exitCode = error.exitCode;
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    await processes?.dispose();
  }
}
