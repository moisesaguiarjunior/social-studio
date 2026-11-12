import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'draft upstream patches reject baseline defects and pass capture',
    () async {
      final result = await Process.run('python3', [
        'tool/check_upstream_capture.py',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
