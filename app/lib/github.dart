import 'package:app/event.dart';
import 'package:github/server.dart' hide Event;
import 'package:meta/meta.dart';

/// Post the comment as a commit comment on GitHub
Future<void> postCommitComment(
  String comment, {
  @required final Event event,
  @required final String commitSha,
  @required final String githubToken,
  final int lineNumber,
  final String fileRelativePath,
  @required Future<void> Function(dynamic error, dynamic stack) onError,
}) async {
  try {
    final GitHub github =
        createGitHubClient(auth: Authentication.withToken(githubToken));
    final Repository repo = await github.repositories
        .getRepository(RepositorySlug.full(event.repoSlug));
    final RepositoryCommit commit =
        await github.repositories.getCommit(repo.slug(), commitSha);
    await github.repositories.createCommitComment(
      repo.slug(),
      commit,
      body: comment,
      path: fileRelativePath,
      line: lineNumber,
    );
  } catch (e, s) {
    await onError(e, s);
  }
}
