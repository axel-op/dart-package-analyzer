import 'dart:convert';
import 'dart:io';

import 'package:app/comments.dart';
import 'package:github/server.dart';
import 'package:meta/meta.dart';

final bool testing = Platform.environment['TESTING'] == 'true';
final Map<String, Future<_Diff>> _diffs = {};

GitHub _getClient(String token) =>
    createGitHubClient(auth: Authentication.withToken(token));

/// Posts the comment as a commit comment on GitHub
Future<void> postCommitComment(
  Comment comment, {
  @required final String repositorySlug,
  @required final String githubToken,
  @required Future<void> Function(dynamic error, dynamic stack) onError,
}) async {
  try {
    final GitHub github = _getClient(githubToken);
    final RepositorySlug slug = RepositorySlug.full(repositorySlug);
    final RepositoryCommit commit =
        await github.repositories.getCommit(slug, comment.commitSha);
    int position;
    if (comment.lineInFile != null) {
      final _Diff diff = await _getDiff(
        commitSha: comment.commitSha,
        repositorySlug: slug,
        githubToken: githubToken,
      );
      position = diff.getPosition(comment.file, comment.lineInFile);
    }
    if (comment.lineInFile == null || position != null) {
      if (testing) {
        stderr.writeln('A comment would be posted with ' +
            const JsonEncoder.withIndent('  ').convert(
              jsonEncode(<String, dynamic>{
                'path': comment.file,
                'position': position,
                'body': comment.body,
              }),
            ));
      } else {
        await github.repositories.createCommitComment(
          slug,
          commit,
          body: comment.body,
          path: comment.file,
          position: position,
        );
      }
    }
  } catch (e, s) {
    await onError(e, s);
  }
}

/// Gets a diff and parses it
Future<_Diff> _getDiff({
  @required String commitSha,
  @required String githubToken,
  @required RepositorySlug repositorySlug,
}) async =>
    _diffs.putIfAbsent(commitSha, () async {
      final GitHub client = _getClient(githubToken);
      return _parseDiff(await client.repositories.getCommitDiff(
        repositorySlug,
        commitSha,
      ));
    });

/// Parses a diff and returns a [_Diff] object
_Diff _parseDiff(String diffStr) {
  final _Diff diff = _Diff();
  String currentFile;
  int diffPosition;
  int nextLineInFile;
  for (final line in diffStr.split('\n')) {
    if (line.startsWith('diff')) {
      currentFile = null;
    } else if (line.startsWith('+++ ')) {
      const String prefix = r'\b';
      currentFile = line.substring(4).substring(prefix.length);
      diffPosition = 0;
    } else if (line.startsWith('@@') &&
        currentFile != null &&
        diffPosition != null) {
      if (diffPosition != 0) diffPosition += 1;
      final List<String> indexes = RegExp(r'\+[0-9]+,[0-9]+')
          .firstMatch(line)
          .group(0)
          .substring(1)
          .split(',');
      nextLineInFile = int.parse(indexes[0]);
    } else if (currentFile != null &&
        diffPosition != null &&
        nextLineInFile != null) {
      diffPosition += 1;
      if (line.startsWith('+') || line.startsWith(' ')) {
        diff._setPosition(
          currentFile,
          lineInFile: nextLineInFile,
          position: diffPosition,
        );
        nextLineInFile += 1;
      }
    }
  }
  return diff;
}

class _Diff {
  final Map<String, Map<int, int>> _files = {};

  int getPosition(String file, int lineInFile) {
    final Map<int, int> lines = _files[file];
    if (lines == null) return null;
    return lines[lineInFile];
  }

  void _setPosition(
    String file, {
    @required int lineInFile,
    @required int position,
  }) =>
      _files.putIfAbsent(file, () => <int, int>{})[lineInFile] = position;
}
