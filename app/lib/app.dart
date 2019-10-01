import 'package:app/event.dart';
import 'package:app/result.dart';
import 'package:github/server.dart' hide Event;
import 'package:meta/meta.dart';

/// Post the comment as a commit comment on GitHub
Future<void> postCommitComment(
    String comment,
    {@required
        final Event event,
    @required
        final String commitSha,
    @required
        final String githubToken,
    final int lineNumber,
    final String fileRelativePath,
    @required
        Future<void> Function(dynamic error, dynamic stack) onError}) async {
  try {
    final GitHub github =
        createGitHubClient(auth: Authentication.withToken(githubToken));
    final Repository repo = await github.repositories
        .getRepository(RepositorySlug.full(event.repoSlug));
    final RepositoryCommit commit =
        await github.repositories.getCommit(repo.slug(), commitSha);
    await github.repositories.createCommitComment(repo.slug(), commit,
        body: comment, path: fileRelativePath, position: lineNumber);
  } catch (e, s) {
    await onError(e, s);
  }
}

/// Build message to be posted on GitHub
String buildComment(Result result, Event event, String commitSha) {
  String comment = '## Package analysis results for commit $commitSha';
  comment +=
      '\n(version of [pana](https://pub.dev/packages/pana) used: ${result.panaVersion})';
  comment +=
      '\n\n* Health score is **${result.healthScore.toString()} / 100.0**';
  comment +=
      '\n* Maintenance score is **${result.maintenanceScore.toString()} / 100.0**';
  if (result.healthSuggestions.isNotEmpty ||
      result.maintenanceSuggestions.isNotEmpty) {
    comment += '\n\n### Issues';
  }
  if (result.healthSuggestions.isNotEmpty) {
    comment += '\n#### Health';
    result.healthSuggestions.forEach((s) => comment += _stringSuggestion(s));
  }
  if (result.maintenanceSuggestions.isNotEmpty) {
    comment += '\n#### Maintenance';
    result.maintenanceSuggestions
        .forEach((s) => comment += _stringSuggestion(s));
  }
  return comment;
}

String _stringSuggestion(Suggestion suggestion) {
  String str = '\n* ';
  if (suggestion.title != null || suggestion.loss != null) {
    str += '**';
    if (suggestion.title != null) str += '${suggestion.title} ';
    if (suggestion.loss != null) {
      str += '(${suggestion.loss.toString()} points)';
    }
    str += '**: ';
  }
  ;
  str += suggestion.description.replaceAll(RegExp(r'(\n)+'), '\n  *');
  return str;
}

/// Process the output of the pana command and returns the [Result]
Result processOutput(Map<String, dynamic> output) {
  final scores = output['scores'];
  final String panaVersion = output['runtimeInfo']['panaVersion'];
  final double healthScore = scores['health'];
  final double maintenanceScore = scores['maintenance'];
  final List<Suggestion> maintenanceSuggestions = [];
  final List<Suggestion> healthSuggestions = [];
  final List<LineSuggestion> lineSuggestions = [];

  if (output.containsKey('suggestions')) {
    final List<Map<String, dynamic>> suggestions =
        List.castFrom<dynamic, Map<String, dynamic>>(output['suggestions']);
    maintenanceSuggestions.addAll(_parseSuggestions(suggestions));
  }

  if (output.containsKey('health')) {
    final Map<String, dynamic> health = output['health'];
    if (health.containsKey('suggestions')) {
      final List<Map<String, dynamic>> suggestions =
          List.castFrom<dynamic, Map<String, dynamic>>(health['suggestions']);
      healthSuggestions.addAll(_parseSuggestions(suggestions));
    }
  }

  if (output.containsKey('dartFiles')) {
    final Map<String, dynamic> dartFiles = output['dartFiles'];
    for (final String file in dartFiles.keys) {
      final Map<String, dynamic> details = output[file];
      if (details.containsKey('codeProblems')) {
        List<Map<String, dynamic>> problems =
            List.castFrom<dynamic, Map<String, dynamic>>(
                output['codeProblems']);
        lineSuggestions.addAll(problems.map((jsonObj) => LineSuggestion(
              lineNumber: jsonObj['line'],
              description: jsonObj['description'],
              relativePath: jsonObj['file'],
            )));
      }
    }
  }

  return Result(
    panaVersion: panaVersion,
    maintenanceScore: maintenanceScore,
    healthScore: healthScore,
    maintenanceSuggestions: maintenanceSuggestions,
    healthSuggestions: healthSuggestions,
    lineSuggestions: lineSuggestions,
  );
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
