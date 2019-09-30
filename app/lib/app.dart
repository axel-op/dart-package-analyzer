import 'package:app/event.dart';
import 'package:app/result.dart';

/// Build message to be posted on GitHub
String buildComment(Result result, Event event, String commitSha) {
  String comment = '## Package analysis results for commit $commitSha';
  comment +=
      '\n(version of [pana](https://pub.dev/packages/pana) used: ${result.pana_version}';
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
  if (event is PullRequest) {
    comment +=
        '\n\n_This comment is posted only because at least one of the scores is below 100. If no comment appears after the next commit, then no problem will remain._';
  }
  return comment;
}

String _stringSuggestion(Suggestion s) {
  return '\n* **${s.title} (${s.loss.toString()} points)**: ${s.description}';
}

/// Process the output of the pana command
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
