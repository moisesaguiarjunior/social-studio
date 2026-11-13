import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  for (final mutateMedia in [false, true]) {
    test(
      mutateMedia
          ? 'replacing valid media during render rejects the export'
          : 'frozen capture preserves the job and strips source metadata',
      () async {
        final temp = Directory.systemTemp.createTempSync('frozen-story-');
        addTearDown(() => temp.deleteSync(recursive: true));
        final package = Directory(p.join(temp.path, 'flutter/social_studio'))
          ..createSync(recursive: true);
        void copyTree(Directory source, Directory destination) {
          destination.createSync(recursive: true);
          for (final entry in source.listSync()) {
            final target = p.join(destination.path, p.basename(entry.path));
            if (entry is Directory) copyTree(entry, Directory(target));
            if (entry is File) {
              entry.copySync(target);
            }
          }
        }

        for (final name in ['bin', 'lib', 'tool', 'assets']) {
          copyTree(Directory(name), Directory(p.join(package.path, name)));
        }
        for (final name in ['pubspec.yaml', 'pubspec.lock']) {
          File(name).copySync(p.join(package.path, name));
        }
        Directory(p.join(package.path, '.dart_tool')).createSync();
        for (final name in ['package_config.json', 'package_graph.json']) {
          File('.dart_tool/$name')
              .copySync(p.join(package.path, '.dart_tool', name));
        }
        final spec = Directory(p.join(temp.path, 'spec/desktop-story'));
        copyTree(Directory('../../spec/desktop-story'), spec);
        final profile = File(p.join(spec.path, 'story-profile.json'));
        final Object? decoded = jsonDecode(profile.readAsStringSync());
        if (decoded is! Map<String, Object?>) {
          throw StateError('Expected profile');
        }
        profile.writeAsStringSync(
          jsonEncode({...decoded, 'width': 96, 'height': 160}),
        );
        final font = File(
          p.join(temp.path, 'probes/phase0/assets/Roboto-Regular.ttf'),
        );
        font.parent.createSync(recursive: true);
        File('../../probes/phase0/assets/Roboto-Regular.ttf')
            .copySync(font.path);
        final ffmpeg = Platform.environment['FLUVIE_FFMPEG'] ?? 'ffmpeg';
        Future<void> encode(List<String> arguments) async {
          final result = await Process.run(ffmpeg, [
            '-v',
            'error',
            ...arguments,
          ]);
          expect(result.exitCode, 0, reason: '${result.stderr}');
        }

        await encode([
          '-f',
          'lavfi',
          '-i',
          'color=blue:s=16x16',
          '-frames:v',
          '1',
          p.join(temp.path, 'blue.png'),
        ]);
        File('test/fixtures/tagged_red.png')
            .copySync(p.join(temp.path, 'red.png'));
        final imageBytes = latin1.decode(
          File(p.join(temp.path, 'red.png')).readAsBytesSync(),
        );
        expect(imageBytes, contains('SyntheticPhotoDevice'));
        expect(imageBytes, contains('SyntheticPhotoLocation'));
        await encode([
          '-f',
          'lavfi',
          '-i',
          'anullsrc=r=8000:cl=mono',
          '-t',
          '1',
          '-metadata',
          'artist=SyntheticAudioDevice',
          '-metadata',
          'comment=SyntheticAudioLocation',
          p.join(temp.path, 'audio.wav'),
        ]);
        final ffprobe =
            Platform.environment['FFPROBE'] ??
            (p.dirname(ffmpeg) == '.'
                ? 'ffprobe'
                : p.join(p.dirname(ffmpeg), 'ffprobe'));
        Future<String> metadata(String path) async {
          final result = await Process.run(ffprobe, [
            '-v',
            'error',
            '-show_entries',
            'format_tags:stream_tags',
            '-of',
            'json',
            path,
          ]);
          expect(result.exitCode, 0, reason: '${result.stderr}');
          final Object? tags = jsonDecode(result.stdout.toString());
          expect(tags, isA<Map<String, Object?>>());
          return jsonEncode(tags);
        }

        final inputTags = await metadata(p.join(temp.path, 'audio.wav'));
        expect(inputTags, contains('SyntheticAudioDevice'));
        expect(inputTags, contains('SyntheticAudioLocation'));
        final source = File(p.join(temp.path, 'job.json'));
        final original = <String, Object?>{
          'version': 1,
          'template': 'story-photo-v1',
          'image': 'red.png',
          'audio': 'audio.wav',
          'durationMs': 12000,
          'coverMs': 3000,
          'captions': [
            {'startMs': 1000, 'endMs': 5000, 'text': 'Original caption'},
          ],
        };
        source.writeAsStringSync(jsonEncode(original));
        final replacement = File(p.join(temp.path, 'replacement.json'))
          ..writeAsStringSync(
            jsonEncode({
              ...original..remove('image'),
              'scenes': [
                {'image': 'red.png', 'durationMs': 4000},
                {'image': 'blue.png', 'durationMs': 8000},
              ],
              'captions': [
                {'startMs': 1000, 'endMs': 5000, 'text': 'Changed caption'},
              ],
            }),
          );
        final wrapper = File(p.join(temp.path, 'encoder'))
          ..writeAsStringSync('''#!/usr/bin/env python3
import os, shutil, sys
if (sys.argv[1:] == ['-version'] and os.environ['TEST_MEDIA'] == 'false') or (os.environ['TEST_MEDIA'] == 'true' and any(a.startswith('select=eq') for a in sys.argv[1:])):
    shutil.copyfile(os.environ['TEST_REPLACEMENT'], os.environ['TEST_SOURCE'])
os.execvp(os.environ['TEST_FFMPEG'], [os.environ['TEST_FFMPEG'], *sys.argv[1:]])
''');
        expect((await Process.run('chmod', ['+x', wrapper.path])).exitCode, 0);
        final output = p.join(temp.path, 'output');
        final result = await Process.run(
          'dart',
          ['run', 'bin/social_studio.dart', 'render', source.path, output],
          workingDirectory: package.path,
          environment: {
            'FLUVIE_FFMPEG': wrapper.path,
            'TEST_FFMPEG': ffmpeg,
            'TEST_MEDIA': '$mutateMedia',
            'TEST_SOURCE': mutateMedia
                ? p.join(temp.path, 'red.png')
                : source.path,
            'TEST_REPLACEMENT': mutateMedia
                ? p.join(temp.path, 'blue.png')
                : replacement.path,
          },
        );
        if (mutateMedia) {
          expect(result.exitCode, 1);
          expect(
            result.stderr,
            contains('A source media file changed after validation'),
          );
          expect(Directory(output).existsSync(), isFalse);
          expect(
            temp.listSync().where(
              (entry) => p.basename(entry.path).startsWith('.social-studio-'),
            ),
            isEmpty,
          );
          return;
        }
        expect(
          result.exitCode,
          0,
          reason: '${result.stderr}\n${result.stdout}',
        );
        expect(
          source.readAsStringSync(),
          contains('Changed caption'),
          reason: 'The source really changed before capture',
        );
        for (final name in ['story.mp4', 'cover.png']) {
          final path = p.join(output, name);
          final tags = await metadata(path);
          final bytes = latin1.decode(File(path).readAsBytesSync());
          for (final marker in [
            'SyntheticPhotoDevice',
            'SyntheticPhotoLocation',
            'SyntheticAudioDevice',
            'SyntheticAudioLocation',
          ]) {
            expect(tags, isNot(contains(marker)), reason: '$name decoded tags');
            expect(bytes, isNot(contains(marker)), reason: '$name payload');
          }
        }
        final html = File(p.join(output, 'review.html')).readAsStringSync();
        expect(html, contains('Original caption'));
        expect(html, isNot(contains('Scene 2')));
        final srt = File(p.join(output, 'captions.srt')).readAsStringSync();
        expect(srt, contains('Original caption'));
        expect(srt, isNot(contains('Changed caption')));
        final pixels = await Process.run(ffmpeg, [
          '-v',
          'error',
          '-i',
          p.join(output, 'story.mp4'),
          '-vf',
          'select=eq(n\\,180),scale=1:1',
          '-frames:v',
          '1',
          '-f',
          'rawvideo',
          '-pix_fmt',
          'rgb24',
          '-',
        ], stdoutEncoding: null);
        expect(pixels.exitCode, 0);
        final bytes = pixels.stdout;
        if (bytes is! List<int>) throw StateError('Expected decoded pixel');
        expect(bytes.length, 3);
        expect(
          bytes[0],
          greaterThan(200),
          reason: 'Original red photo at six seconds',
        );
        expect(
          bytes[2],
          lessThan(30),
          reason: 'Replacement blue scene must not appear',
        );
        expect(
          temp.listSync().where(
            (entry) => p.basename(entry.path).startsWith('.social-studio-'),
          ),
          isEmpty,
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
