import 'dart:io';

import 'package:github/server.dart';
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
      throw ArgumentError('No value were given for the argument \'$name\'.');
    }
    return v;
  }
}

class Inputs {
  final String sourcePath;
  final String packagePath;
  final String flutterPath;
  final String githubToken;
  final String commitSha;
  final String repositorySlug;
  final CheckRunAnnotationLevel minAnnotationLevel;

  Inputs._({
    @required this.commitSha,
    @required this.flutterPath,
    @required this.githubToken,
    @required this.packagePath,
    @required this.sourcePath,
    @required this.repositorySlug,
    @required this.minAnnotationLevel,
  });
}

Future<Inputs> getInputs() async {
  const Map<String, CheckRunAnnotationLevel> annotationMapping = {
    'info': CheckRunAnnotationLevel.notice,
    'warning': CheckRunAnnotationLevel.warning,
    'error': CheckRunAnnotationLevel.failure,
  };
  const String flutterPath = '/flutter'; // TODO pass this as an env var
  final String repositorySlug = Platform.environment['GITHUB_REPOSITORY'];
  final String commitSha = Platform.environment['GITHUB_SHA'];
  String githubToken;
  CheckRunAnnotationLevel minAnnotationLevel;
  String packagePath;
  String repoPath;
  githubToken = githubTokenInput.value;
  minAnnotationLevel =
      annotationMapping[minAnnotationLevelInput.value.toLowerCase()];
  if (minAnnotationLevel == null) {
    throw ArgumentError.value(
        minAnnotationLevelInput.value, 'minAnnotationLevel');
  }
  packagePath = packagePathInput.value ?? '';
  if (packagePath.startsWith('/')) {
    packagePath = packagePath.substring(1);
  }
  if (packagePath.endsWith('/')) {
    packagePath = packagePath.substring(0, packagePath.length - 1);
  }
  repoPath = Platform.environment['GITHUB_WORKSPACE'];
  if (repoPath.endsWith('/')) {
    repoPath = repoPath.substring(0, repoPath.length - 1);
  }

  return Inputs._(
    commitSha: commitSha,
    flutterPath: flutterPath,
    githubToken: githubToken,
    packagePath: packagePath,
    repositorySlug: repositorySlug,
    sourcePath: '$repoPath/$packagePath',
    minAnnotationLevel: minAnnotationLevel,
  );
}
