import 'dart:io';

import 'package:args/args.dart';
import 'package:meta/meta.dart';

const List<_Argument> _arguments = [
  _Argument(
    'repo_path',
    'r',
    nullable: false,
    canBeEmpty: true,
  ),
  _Argument(
    'github_token',
    't',
    nullable: false,
    canBeEmpty: false,
    publicName: 'githubToken',
  ),
  _Argument(
    'event_payload',
    'e',
    nullable: false,
    canBeEmpty: false,
    publicName: 'eventPayload',
  ),
  _Argument(
    'fluttersdk_path',
    'f',
    nullable: false,
    canBeEmpty: true,
  ),
  _Argument(
    'commit_sha',
    'c',
    nullable: false,
    canBeEmpty: false,
    publicName: 'commitSha',
  ),
  _Argument(
    'max_score',
    'm',
    nullable: true,
    canBeEmpty: true,
    publicName: 'maxScoreToComment',
  ),
  _Argument(
    'package_path',
    'p',
    nullable: true,
    canBeEmpty: true,
    publicName: 'relativePath',
  ),
];

class _Argument {
  final String fullName;
  final String abbr;
  final bool nullable;
  final bool canBeEmpty;
  final String publicName;

  const _Argument(
    this.fullName,
    this.abbr, {
    @required this.nullable,
    @required this.canBeEmpty,
    this.publicName,
  });
}

class Arguments {
  final String sourcePath;
  final String packagePath;
  final String flutterPath;
  final String githubToken;
  final String eventPayload;
  final String commitSha;
  final num maxScoreToComment;

  Arguments._({
    @required this.commitSha,
    @required this.eventPayload,
    @required this.flutterPath,
    @required this.githubToken,
    @required this.maxScoreToComment,
    @required this.packagePath,
    @required this.sourcePath,
  });
}

Arguments parseArgs(List<String> args) {
  final ArgParser argParser = ArgParser();
  _arguments.forEach((arg) => argParser.addOption(
        arg.fullName,
        abbr: arg.abbr,
      ));
  final ArgResults argResults = argParser.parse(args);
  _arguments.forEach((final arg) {
    final dynamic result = argResults[arg.fullName];
    if ((result == null && !arg.nullable) ||
        (result is String && result.isEmpty && !arg.canBeEmpty)) {
      stderr.writeln(
          'No value were given for the argument \'${arg.publicName ?? arg.fullName}\'. Exiting.');
      exit(1);
    }
  });

  String repoPath = argResults['repo_path'];
  if (repoPath.endsWith('/')) {
    repoPath = repoPath.substring(0, repoPath.length - 1);
  }
  final String flutterPath = argResults['fluttersdk_path'];
  final String eventPayload = argResults['event_payload'];
  final String githubToken = argResults['github_token'];
  final String commitSha = argResults['commit_sha'];
  final dynamic maxScoreUnknownType = argResults['max_score'];
  final num maxScore =
      maxScoreUnknownType != null && maxScoreUnknownType is String
          ? num.parse(maxScoreUnknownType)
          : maxScoreUnknownType;
  String packagePath = argResults['package_path'] ?? '';
  packagePath = packagePath.substring(
    packagePath.startsWith('/') ? 1 : 0,
    packagePath.length - (packagePath.endsWith('/') ? 1 : 0),
  );
  final String sourcePath = '$repoPath/$packagePath';

  return Arguments._(
    commitSha: commitSha,
    eventPayload: eventPayload,
    flutterPath: flutterPath,
    githubToken: githubToken,
    maxScoreToComment: maxScore,
    packagePath: packagePath,
    sourcePath: sourcePath,
  );
}
