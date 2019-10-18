import 'dart:io';

import 'package:app/result.dart';
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
      stderr
          .writeln('No value were given for the argument \'$name\'. Exiting.');
      exit(1);
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
  final AnnotationLevel minAnnotationLevel;

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

Inputs getInputs() {
  const String flutterPath = '/flutter'; // TODO pass this as an env var
  final String repositorySlug = Platform.environment['GITHUB_REPOSITORY'];
  final String commitSha = Platform.environment['GITHUB_SHA'];
  AnnotationLevel minAnnotationLevel;
  switch (minAnnotationLevelInput.value.toLowerCase()) {
    case 'info':
      minAnnotationLevel = AnnotationLevel.Info;
      break;
    case 'warning':
      minAnnotationLevel = AnnotationLevel.Warning;
      break;
    case 'error':
      minAnnotationLevel = AnnotationLevel.Error;
      break;
    default:
      throw ArgumentError.value(
          minAnnotationLevelInput.value, 'minAnnotationLevel');
  }
  String repoPath = Platform.environment['GITHUB_WORKSPACE'];
  if (repoPath.endsWith('/')) {
    repoPath = repoPath.substring(0, repoPath.length - 1);
  }
  String packagePath = packagePathInput.value ?? '';
  if (packagePath.startsWith('/')) {
    packagePath = packagePath.substring(1);
  }
  if (packagePath.endsWith('/')) {
    packagePath = packagePath.substring(0, packagePath.length - 1);
  }

  return Inputs._(
    commitSha: commitSha,
    flutterPath: flutterPath,
    githubToken: githubTokenInput.value,
    packagePath: packagePath,
    repositorySlug: repositorySlug,
    sourcePath: '$repoPath/$packagePath',
    minAnnotationLevel: minAnnotationLevel,
  );
}
