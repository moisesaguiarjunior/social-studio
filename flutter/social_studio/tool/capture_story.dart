import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:social_studio/src/story_composition.dart';
import 'package:social_studio/src/story_job.dart';

import 'capture_frame_pump.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final jobPath = _environment('SOCIAL_STUDIO_JOB');
  final spec = _environment('SOCIAL_STUDIO_SPEC');
  final output = Directory(_environment('SOCIAL_STUDIO_FRAMES'));
  final job = StoryJob.load(jobPath, specDirectory: spec);
  final fontBytes = await readLocalFont(
    Platform.environment['SOCIAL_STUDIO_FONT'] ??
        p.join(spec, '../../probes/phase0/assets/Roboto-Regular.ttf'),
  );
  final loader = FontLoader('Roboto')
    ..addFont(Future<ByteData>.value(ByteData.sublistView(fontBytes)));
  await loader.load();
  final transcript = File(p.join(output.path, 'captions.srt'));
  await transcript.writeAsString(job.toSrt());
  testWidgets('captures the validated Story job', (tester) async {
    final scope = resolverScope(
      null,
      networkAllowlist: const NetworkAllowlist(hosts: {}),
    );
    addTearDown(scope.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final video = buildStory(job, transcriptPath: transcript.path);
    await renderVideo(
      video: video,
      outDir: output,
      resolver: scope.resolver,
      defaultFontFamily: 'Roboto',
      pumpWidget: tester.pumpWidget,
      pumpFrame: captureFramePump(fps: video.fps, pump: tester.pump),
      runAsync: tester.runAsync,
      setViewSize: (width, height) {
        tester.view.physicalSize = Size(width.toDouble(), height.toDouble());
        tester.view.devicePixelRatio = 1;
      },
    );
  }, timeout: const Timeout(Duration(minutes: 10)));
}

String _environment(String key) {
  final value = Platform.environment[key];
  if (value == null || value.isEmpty) {
    throw StateError('Missing $key. Use bin/social_studio.dart.');
  }
  return value;
}
