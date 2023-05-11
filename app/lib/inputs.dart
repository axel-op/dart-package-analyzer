import 'dart:convert';
import 'dart:io';

import 'package:app/paths.dart';
import 'package:github_actions_toolkit/github_actions_toolkit.dart';

const Input githubTokenInput = Input(
      'githubToken',
      isRequired: true,
      canBeEmpty: false,
    ),
    packagePathInput = Input(
      'relativePath',
      isRequired: false,
      canBeEmpty: true,
    );

class Inputs {
  /// Token to call the GitHub API
  final String githubToken;

  /// Head SHA of the commit associated to the current workflow
  final String commitSha;

  /// Slug of the repository
  final String repositorySlug;

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
      githubToken: githubTokenInput.value!,
      paths: paths,
      repositorySlug: Platform.environment['GITHUB_REPOSITORY']!,
    );
  }

  Inputs._({
    required this.commitSha,
    required this.githubToken,
    required this.paths,
    required this.repositorySlug,
  });

  static String get _sha {
    final String pathEventPayload = Platform.environment['GITHUB_EVENT_PATH']!;
    final Map<String, dynamic> eventPayload =
        jsonDecode(File(pathEventPayload).readAsStringSync());
    final String commitSha = Platform.environment['GITHUB_SHA']!;
    stderr.writeln('SHA that triggered the workflow: $commitSha');
    final Map<String, dynamic>? pullRequest = eventPayload['pull_request'];
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
}
