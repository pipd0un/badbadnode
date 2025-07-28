// tool/bump_version.dart
// fvm dart run tool/bump_version.dart

import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';
import 'dart:developer' show log;

Future<void> main() async {
  final commitMsg = await _latestCommitMessage();

  final bumpType = _getBumpType(commitMsg);
  if (bumpType == null) {
    log('ℹ️ No bump needed for commit: "$commitMsg"');
    return;
  }

  final file = File('pubspec.yaml');
  final content = await file.readAsString();
  final doc = loadYaml(content);
  final currentVersion = (doc['version'] as String?)?.split('+').first;

  if (currentVersion == null) {
    stderr.writeln('❌ Could not find version in pubspec.yaml');
    exit(1);
  }

  final newVersion = _bumpVersion(currentVersion, bumpType);
  final editor = YamlEditor(content);
  editor.update(['version'], '$newVersion+1');

  await file.writeAsString(editor.toString());

  log('✅ Bumped to $newVersion+1 ($bumpType)');

  await _commitAndTag(newVersion);
}

Future<String> _latestCommitMessage() async {
  final result = await Process.run('git', ['log', '-1', '--pretty=%B']);
  return result.stdout.toString().trim();
}

String? _getBumpType(String msg) {
  if (msg.contains('breaking-change:')) {
    return 'major';
  } else if (msg.contains('feat:')) {
    return 'minor';
  } else if (msg.contains('fix:')) {
    return 'patch';
  }
  return null;
}

String _bumpVersion(String version, String bumpType) {
  final parts = version.split('.').map(int.parse).toList();
  switch (bumpType) {
    case 'major':
      return '${parts[0] + 1}.0.0';
    case 'minor':
      return '${parts[0]}.${parts[1] + 1}.0';
    case 'patch':
      return '${parts[0]}.${parts[1]}.${parts[2] + 1}';
    default:
      throw ArgumentError('Invalid bump type: $bumpType');
  }
}

Future<void> _commitAndTag(String version) async {
  await Process.run('git', ['add', 'pubspec.yaml']);
  await Process.run('git', ['commit', '-m', 'chore(release): v$version']);
  await Process.run('git', ['tag', 'v$version']);
}
