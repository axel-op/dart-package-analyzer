import 'dart:io';

import 'package:meta/meta.dart';

const _Input githubTokenInput = _Input(
  'githubToken',
  nullable: false,
  canBeEmpty: false,
),
    maxScoreInput = _Input(
  'maxScoreToComment',
  nullable: true,
  canBeEmpty: true,
),
    packagePathInput = _Input(
  'relativePath',
  nullable: true,
  canBeEmpty: true,
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
  final num maxScoreToComment;

  Inputs._({
    @required this.commitSha,
    @required this.flutterPath,
    @required this.githubToken,
    @required this.maxScoreToComment,
    @required this.packagePath,
    @required this.sourcePath,
    @required this.repositorySlug,
  });
}

Inputs getInputs() {
  const String flutterPath = '/flutter'; // TODO pass this as an env var
  final num maxScoreToComment =
      num.tryParse(maxScoreInput.value ?? '100') ?? 100;
  final String repositorySlug = Platform.environment['GITHUB_REPOSITORY'];
  final String commitSha = Platform.environment['GITHUB_SHA'];
  String repoPath = Platform.environment['GITHUB_WORKSPACE'];
  if (repoPath.endsWith('/')) {
    repoPath = repoPath.substring(0, repoPath.length - 1);
  }
  String packagePath = packagePathInput.value ?? '';
  packagePath = packagePath.substring(
    packagePath.startsWith('/') ? 1 : 0,
    packagePath.length - (packagePath.endsWith('/') ? 1 : 0),
  );

  return Inputs._(
    commitSha: commitSha,
    flutterPath: flutterPath,
    githubToken: githubTokenInput.value,
    maxScoreToComment: maxScoreToComment,
    packagePath: packagePath,
    repositorySlug: repositorySlug,
    sourcePath: '$repoPath/$packagePath',
  );
}
