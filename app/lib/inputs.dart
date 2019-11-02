import 'dart:convert';
import 'dart:io';

import 'package:github/server.dart';
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
  final String absolutePathToPackage;
  final String eventName;
  final String filesPrefix;
  final String githubToken;
  final String commitSha;
  final String repositorySlug;
  final CheckRunAnnotationLevel minAnnotationLevel;

  factory Inputs() {
    final String repositorySlug = Platform.environment['GITHUB_REPOSITORY'];
    final String eventName = Platform.environment['GITHUB_EVENT_NAME'];
    final String commitSha = _getSHA();
    final String githubToken = githubTokenInput.value;
    final CheckRunAnnotationLevel minAnnotationLevel = _getMinAnnotationLevel();
    final String repoPath = _getRepoPath();
    final String packagePath = packagePathInput.value ?? '';
    final String sourcePath = path.canonicalize('$repoPath/$packagePath');

    return Inputs._(
      absolutePathToPackage: sourcePath,
      commitSha: commitSha,
      eventName: eventName,
      filesPrefix: path.relative(sourcePath, from: repoPath),
      githubToken: githubToken,
      minAnnotationLevel: minAnnotationLevel,
      repositorySlug: repositorySlug,
    );
  }

  Inputs._({
    @required this.commitSha,
    @required this.githubToken,
    @required this.filesPrefix,
    @required this.absolutePathToPackage,
    @required this.repositorySlug,
    @required this.minAnnotationLevel,
    @required this.eventName,
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
    String commitSha = Platform.environment['GITHUB_SHA'];
    String message = 'This action will be run for commit $commitSha';
    final Map<String, dynamic> pullRequest = eventPayload['pull_request'];
    if (pullRequest != null) {
      final String headSha = pullRequest['head']['sha'];
      if (commitSha != headSha) {
        message +=
            ', but as it is a merge commit, the output will be attached to the head commit $headSha';
        commitSha = headSha;
      }
    }
    stderr.writeln(message);
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
