import 'dart:io';

import 'package:path/path.dart' as path;

class Paths {
  final String packageRelativePath;

  Paths({required this.packageRelativePath});

  /// Canonical path to the package to analyze
  String get canonicalPathToPackage =>
      path.canonicalize('$canonicalPathToRepoRoot/$packageRelativePath');

  /// Path to the folder containing the entire repository
  String get canonicalPathToRepoRoot {
    const String envVarWorkspace = 'GITHUB_WORKSPACE';
    final String? repoPath = Platform.environment[envVarWorkspace];
    if (repoPath == null) {
      throw ArgumentError.value(repoPath, envVarWorkspace,
          "Make sure you call 'actions/checkout' in a previous step. Invalid environment variable");
    }
    return repoPath;
  }
}
