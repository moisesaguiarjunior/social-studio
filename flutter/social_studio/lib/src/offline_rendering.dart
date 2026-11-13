import 'dart:io';

/// A Dart HTTP connection was attempted inside the offline capture boundary.
final class OfflineRenderException implements Exception {
  /// Creates an error without including request URLs or supplied content.
  const OfflineRenderException();

  @override
  String toString() =>
      'OfflineRenderException: HTTP is disabled during capture.';
}

/// Runs [capture] in an asynchronous zone that blocks connections from new Dart HTTP clients.
///
/// Complements local-input validation and Fluvie's empty network allowlist.
/// This does not intercept existing clients, raw sockets or native plugins;
/// callers must create their capture resources inside this boundary.
Future<T> runOffline<T>(Future<T> Function() capture) => HttpOverrides.runZoned(
  capture,
  createHttpClient: _OfflineOverrides().createHttpClient,
);

final class _OfflineOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = (_) => 'DIRECT';
    client.connectionFactory = (_, _, _) =>
        throw const OfflineRenderException();
    return client;
  }
}
