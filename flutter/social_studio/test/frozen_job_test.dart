import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  for (final mutateMedia in [false, true]) {
    test(
      mutateMedia
          ? 'replacing valid media during render rejects the export'
          : 'editing the source after validation cannot change captured job',
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

        for (final color in ['red', 'blue']) {
          await encode([
            '-f',
            'lavfi',
            '-i',
            'color=$color:s=16x16',
            '-frames:v',
            '1',
            p.join(temp.path, '$color.png'),
          ]);
        }
        await encode([
          '-f',
          'lavfi',
          '-i',
          'anullsrc=r=8000:cl=mono',
          '-t',
          '1',
          p.join(temp.path, 'audio.wav'),
        ]);
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
