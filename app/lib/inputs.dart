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
  final String filesPrefix;
  final String flutterPath;
  final String githubToken;
  final String commitSha;
  final String repositorySlug;
  final CheckRunAnnotationLevel minAnnotationLevel;

  Inputs._({
    @required this.commitSha,
    @required this.flutterPath,
    @required this.githubToken,
    @required this.filesPrefix,
    @required this.absolutePathToPackage,
    @required this.repositorySlug,
    @required this.minAnnotationLevel,
  });

  static Future<Inputs> getInputs() async {
    const Map<String, CheckRunAnnotationLevel> annotationMapping = {
      'info': CheckRunAnnotationLevel.notice,
      'warning': CheckRunAnnotationLevel.warning,
      'error': CheckRunAnnotationLevel.failure,
    };
    const String flutterPath = '/flutter'; // TODO pass this as an env var
    final String repositorySlug = Platform.environment['GITHUB_REPOSITORY'];
    final String commitSha = Platform.environment['GITHUB_SHA'];
    final String githubToken = githubTokenInput.value;
    final CheckRunAnnotationLevel minAnnotationLevel =
        annotationMapping[minAnnotationLevelInput.value.toLowerCase()];
    if (minAnnotationLevel == null) {
      throw ArgumentError.value(
          minAnnotationLevelInput.value, 'minAnnotationLevel');
    }
    const String envVarWorkspace = 'GITHUB_WORKSPACE';
    final String repoPath = Platform.environment[envVarWorkspace];
    if (repoPath == null) {
      throw ArgumentError.value(repoPath, envVarWorkspace,
          "Did you call 'actions/checkout' in a previous step? Invalid environment variable");
    }
    final String packagePath = packagePathInput.value ?? '';
    final String sourcePath = path.canonicalize('$repoPath/$packagePath');

    return Inputs._(
      commitSha: commitSha,
      flutterPath: flutterPath,
      githubToken: githubToken,
      filesPrefix: path.relative(sourcePath, from: repoPath),
      repositorySlug: repositorySlug,
      absolutePathToPackage: sourcePath,
      minAnnotationLevel: minAnnotationLevel,
    );
  }
}
