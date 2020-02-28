import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

class Paths {
  final String packageRelativePath;
  final String optionsRelativePath;

  Paths({
    @required this.packageRelativePath,
    @required this.optionsRelativePath,
  });

  /// Canonical path to the package to analyze
  String get canonicalPathToPackage =>
      path.canonicalize('$canonicalPathToRepoRoot/$packageRelativePath');

  /// Path to the folder containing the entire repository
  String get canonicalPathToRepoRoot {
    const String envVarWorkspace = 'GITHUB_WORKSPACE';
    final String repoPath = Platform.environment[envVarWorkspace];
    if (repoPath == null) {
      throw ArgumentError.value(repoPath, envVarWorkspace,
          "Make sure you call 'actions/checkout' in a previous step. Invalid environment variable");
    }
    return repoPath;
  }

  /// Canonical path to analysis options file
  String get canonicalPathToAnalysisOptions =>
      optionsRelativePath != null && optionsRelativePath.isNotEmpty
          ? path.canonicalize('$canonicalPathToPackage/$optionsRelativePath')
          : null;
}
