import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Copies the runnable checkout into [root] with a small synthetic canvas.
///
/// Keeps the canonical spec and font; copies only package sources and resolved
/// package configuration so CLI regressions need no network or dependency fetch.
Directory createDesktopCheckout(Directory root) {
  final package = Directory(p.join(root.path, 'flutter/social_studio'));
  for (final name in ['bin', 'lib', 'tool', 'assets']) {
    _copyTree(Directory(name), Directory(p.join(package.path, name)));
  }
  for (final name in ['pubspec.yaml', 'pubspec.lock']) {
    File(name).copySync(p.join(package.path, name));
  }
  Directory(p.join(package.path, '.dart_tool')).createSync();
  for (final name in ['package_config.json', 'package_graph.json']) {
    File('.dart_tool/$name').copySync(p.join(package.path, '.dart_tool', name));
  }
  final spec = Directory(p.join(root.path, 'spec/desktop-story'));
  _copyTree(Directory('../../spec/desktop-story'), spec);
  final profile = File(p.join(spec.path, 'story-profile.json'));
  final Object? decoded = jsonDecode(profile.readAsStringSync());
  if (decoded is! Map<String, Object?>) throw StateError('Expected profile');
  profile.writeAsStringSync(
    jsonEncode({...decoded, 'width': 96, 'height': 160}),
  );
  final font = File(
    p.join(root.path, 'probes/phase0/assets/Roboto-Regular.ttf'),
  );
  font.parent.createSync(recursive: true);
  File('../../probes/phase0/assets/Roboto-Regular.ttf').copySync(font.path);
  return package;
}

void _copyTree(Directory source, Directory destination) {
  destination.createSync(recursive: true);
  for (final entry in source.listSync()) {
    final target = p.join(destination.path, p.basename(entry.path));
    if (entry is Directory) _copyTree(entry, Directory(target));
    if (entry is File) entry.copySync(target);
  }
}
