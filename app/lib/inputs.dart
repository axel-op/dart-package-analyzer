import 'dart:convert';
import 'dart:io';

import 'package:app/paths.dart';
import 'package:github/github.dart';
import 'package:meta/meta.dart';

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
      throw ArgumentError('No value was given for the argument \'$name\'.');
    }
    return v;
  }
}

class Inputs {
  /// Token to call the GitHub API
  final String githubToken;

  /// Head SHA of the commit associated to the current workflow
  final String commitSha;

  /// Slug of the repository
  final String repositorySlug;

  /// Minimum level of the diff annotations
  final CheckRunAnnotationLevel minAnnotationLevel;

  final Paths paths;

  factory Inputs() {
    final paths = Paths(packageRelativePath: packagePathInput.value ?? '');

    if (!Directory(paths.canonicalPathToPackage).existsSync()) {
      throw ArgumentError.value(
          paths.canonicalPathToPackage,
          packagePathInput.name,
          'This directory doesn\'t exist in your repository');
    }

    return Inputs._(
      commitSha: _sha,
      githubToken: githubTokenInput.value,
      minAnnotationLevel: _minAnnotationLevel,
      paths: paths,
      repositorySlug: Platform.environment['GITHUB_REPOSITORY'],
    );
  }

  Inputs._({
    @required this.commitSha,
    @required this.githubToken,
    @required this.minAnnotationLevel,
    @required this.paths,
    @required this.repositorySlug,
  });

  static String get _sha {
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

  static CheckRunAnnotationLevel get _minAnnotationLevel {
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
