import 'package:app/event.dart';
import 'package:app/result.dart';
import 'package:github/server.dart' hide Event;
import 'package:meta/meta.dart';

/// Post the comment as a commit comment on GitHub
Future<void> postCommitComment(String comment,
    {@required Event event,
    @required String commitSha,
    @required String githubToken,
    @required void Function(dynamic error, dynamic stack) onError}) async {
  try {
    final GitHub github =
        createGitHubClient(auth: Authentication.withToken(githubToken));
    final Repository repo = await github.repositories
        .getRepository(RepositorySlug.full(event.repoSlug));
    final RepositoryCommit commit =
        await github.repositories.getCommit(repo.slug(), commitSha);
    await github.repositories
        .createCommitComment(repo.slug(), commit, body: comment);
  } catch (e, s) {
    onError(e, s);
  }
}

/// Build message to be posted on GitHub
String buildComment(Result result, Event event, String commitSha) {
  String comment = '## Package analysis results for commit $commitSha';
  comment +=
      '\n(version of [pana](https://pub.dev/packages/pana) used: ${result.pana_version})';
  comment +=
      '\n\n* Health score is **${result.health_score.toString()} / 100.0**';
  comment +=
      '\n* Maintenance score is **${result.maintenance_score.toString()} / 100.0**';
  if (result.health_suggestions.isNotEmpty ||
      result.maintenance_suggestions.isNotEmpty) {
    comment += '\n\n### Problems';
  }
  if (result.health_suggestions.isNotEmpty) {
    comment += '\n#### Health';
    result.health_suggestions.forEach((s) => comment += _stringSuggestion(s));
  }
  if (result.maintenance_suggestions.isNotEmpty) {
    comment += '\n#### Maintenance';
    result.maintenance_suggestions
        .forEach((s) => comment += _stringSuggestion(s));
  }
  return comment;
}

String _stringSuggestion(Suggestion s) {
  return '\n* **${s.title} (${s.loss.toString()} points)**: ${s.description}';
}

/// Process the output of the pana command and returns the [Result]
Result processOutput(Map<String, dynamic> output) {
  final scores = output['scores'];
  final Result result = Result(
      pana_version: output['runtimeInfo']['panaVersion'],
      health_score: scores['health'],
      maintenance_score: scores['maintenance']);

  if (output.containsKey('suggestions')) {
    final List<Map<String, dynamic>> suggestions =
        List.castFrom<dynamic, Map<String, dynamic>>(output['suggestions']);
    _parseSuggestions(suggestions).forEach(result.addMaintenanceSuggestion);
  }

  if (output.containsKey('health')) {
    final Map<String, dynamic> health = output['health'];
    if (health.containsKey('suggestions')) {
      final List<Map<String, dynamic>> suggestions =
          List.castFrom<dynamic, Map<String, dynamic>>(health['suggestions']);
      _parseSuggestions(suggestions).forEach(result.addHealthSuggestion);
    }
  }

  return result;
}

List<Suggestion> _parseSuggestions(List<Map<String, dynamic>> list) {
  return list
      .map((s) => Suggestion(
            description: s['description'],
            title: s['title'],
            loss: s['score'],
          ))
      .toList();
}
