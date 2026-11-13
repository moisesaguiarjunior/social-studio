import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:social_studio/src/offline_rendering.dart';

void main() {
  test('capture reads local files across asynchronous work', () async {
    final directory = await Directory.systemTemp.createTemp('offline-story-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/caption.txt');
    await file.writeAsString('Synthetic caption');
    expect(
      await runOffline(() async => file.readAsString()),
      'Synthetic caption',
    );
  });

  test(
    'intentional HTTP attempt fails after an asynchronous boundary',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var requests = 0;
      server.listen((request) {
        requests++;
        request.response.close();
      });
      final url = Uri.parse('http://127.0.0.1:${server.port}/synthetic.png');
      // Prove the endpoint works; only the guarded attempt must be rejected.
      final control = HttpClient();
      addTearDown(() => control.close(force: true));
      final response = await (await control.getUrl(url)).close();
      await response.drain<void>();
      expect(requests, 1);
      final previous = HttpOverrides.current;
      await expectLater(
        runOffline(() async {
          await Future<void>.delayed(Duration.zero);
          final client = HttpClient();
          try {
            await (await client.getUrl(url)).close();
          } finally {
            client.close(force: true);
          }
        }),
        throwsA(isA<OfflineRenderException>()),
      );
      expect(
        requests,
        1,
        reason: 'The guarded request never reaches the server',
      );
      expect(HttpOverrides.current, same(previous));
      expect(await runOffline(() async => 'next render'), 'next render');
    },
  );
}
