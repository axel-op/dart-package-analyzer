import 'dart:convert';
import 'dart:io';

import 'package:github/github.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

const _Input githubTokenInput = _Input(
  'githubToken',
  nullable: false,
  canBeEmpty: false,
),
    packagePathInput = _Input(
  'relativePath',
  nullable: true,
  canBeEmpty: true,
),
    minAnnotationLevelInput = _Input(
  'minAnnotationLevel',
  nullable: false,
  canBeEmpty: false,
);

class _Input {
  final String name;
  final bool nullable;
  final bool canBeEmpty;

  const _Input(
    this.name, {
    @required this.nullable,
    @required this.canBeEmpty,
  });

  String get value {
    final String v = Platform
        .environment['INPUT_${name.toUpperCase().replaceAll(" ", "_")}'];
    if ((v == null && !nullable) || (v != null && v.isEmpty && !canBeEmpty)) {
      throw ArgumentError('No value were given for the argument \'$name\'.');
    }
    return v;
  }
}

class Inputs {
  /// Absolute path to the package that will be analyzed
  final String absolutePathToPackage;

  /// Relative path to the package from the root of the repository
  final String pathFromRepoRoot;

  /// Token to call the GitHub API
  final String githubToken;

  /// Head SHA of the commit associated to the current workflow
  final String commitSha;

  /// Slug of the repository
  final String repositorySlug;

  /// Minimum level of the diff annotations
  final CheckRunAnnotationLevel minAnnotationLevel;

  factory Inputs() {
    final String repoPath = _getRepoPath();
    final String packagePath = packagePathInput.value ?? '';
    final String sourcePath = path.canonicalize('$repoPath/$packagePath');

    return Inputs._(
      absolutePathToPackage: sourcePath,
      commitSha: _getSHA(),
      pathFromRepoRoot: path.relative(sourcePath, from: repoPath),
      githubToken: githubTokenInput.value,
      minAnnotationLevel: _getMinAnnotationLevel(),
      repositorySlug: Platform.environment['GITHUB_REPOSITORY'],
    );
  }

  Inputs._({
    @required this.commitSha,
    @required this.githubToken,
    @required this.pathFromRepoRoot,
    @required this.absolutePathToPackage,
    @required this.repositorySlug,
    @required this.minAnnotationLevel,
  });

  static String _getRepoPath() {
    const String envVarWorkspace = 'GITHUB_WORKSPACE';
    final String repoPath = Platform.environment[envVarWorkspace];
    if (repoPath == null) {
      throw ArgumentError.value(repoPath, envVarWorkspace,
          "Did you call 'actions/checkout' in a previous step? Invalid environment variable");
    }
    return repoPath;
  }

  static String _getSHA() {
    final String pathEventPayload = Platform.environment['GITHUB_EVENT_PATH'];
    final Map<String, dynamic> eventPayload =
        jsonDecode(File(pathEventPayload).readAsStringSync());
    final String commitSha = Platform.environment['GITHUB_SHA'];
    stderr.writeln('SHA that triggered the workflow: $commitSha');
    final Map<String, dynamic> pullRequest = eventPayload['pull_request'];
    if (pullRequest != null) {
      final String baseSha = pullRequest['base']['sha'];
      final String headSha = pullRequest['head']['sha'];
      if (commitSha != headSha) {
        stderr.writeln('Base SHA: $baseSha');
        stderr.writeln('Head SHA: $headSha');
        return headSha;
      }
    }
    return commitSha;
  }

  static CheckRunAnnotationLevel _getMinAnnotationLevel() {
    const Map<String, CheckRunAnnotationLevel> annotationMapping = {
      'info': CheckRunAnnotationLevel.notice,
      'warning': CheckRunAnnotationLevel.warning,
      'error': CheckRunAnnotationLevel.failure,
    };
    final CheckRunAnnotationLevel level =
        annotationMapping[minAnnotationLevelInput.value.toLowerCase()];
    if (level == null) {
      throw ArgumentError.value(
          minAnnotationLevelInput.value, 'minAnnotationLevel');
    }
    return level;
  }
}
