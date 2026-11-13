import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:social_studio/src/offline_rendering.dart';

import '../../tool/capture_story.dart' as capture;

// Exercise the production entry point unchanged. The binding injects a request
// where Fluvie performs real asynchronous work, inside the capture's own scope.
Future<void> main() async {
  final binding = _HttpAttemptBinding();
  tearDownAll(() {
    expect(binding.attempts, greaterThan(0));
  });
  await capture.main();
}

final class _HttpAttemptBinding extends AutomatedTestWidgetsFlutterBinding {
  int attempts = 0;

  @override
  Future<T?> runAsync<T>(Future<T> Function() callback) =>
      super.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
        final client = HttpClient();
        try {
          await expectLater(
            () => client.getUrl(
              Uri.parse('http://127.0.0.1:1/synthetic-capture-probe'),
            ),
            throwsA(isA<OfflineRenderException>()),
            reason:
                'The production capture must reject the injected HTTP attempt',
          );
          attempts++;
        } finally {
          client.close(force: true);
        }
        return callback();
      });
}
