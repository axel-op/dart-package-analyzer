import 'package:app/event.dart';
import 'package:app/result.dart';

/// Build message to be posted on GitHub
String buildComment(Result result, Event event, String commitSha) {
  final Map<String, List<Suggestion>> suggestions = {
    'General': result.generalSuggestions,
    'Health': result.healthSuggestions,
    'Maintenance': result.maintenanceSuggestions,
  };

  String comment = '## Package analysis results for commit $commitSha'
      '\n(version of [pana](https://pub.dev/packages/pana) used: ${result.panaVersion})'
      '\n\n* Health score is **${result.healthScore.toString()} / 100.0**'
      '\n* Maintenance score is **${result.maintenanceScore.toString()} / 100.0**'
      '\n*Please note that 50% of the overall score of your package on the [Pub site](https://pub.dev/help) will be based on its popularity ; 30% on its health score ; and 20% on its maintenance score.*';
  if (suggestions.values.where((l) => l.isNotEmpty).isNotEmpty) {
    comment += '\n\n### Issues';
  }
  for (final MapEntry<String, List<Suggestion>> entry in suggestions.entries) {
    if (entry.value.isNotEmpty) {
      comment += '\n#### ${entry.key}';
      entry.value.forEach((s) => comment += _stringSuggestion(s));
    }
  }
  return comment;
}

String _stringSuggestion(Suggestion suggestion) {
  String str = '\n* ';
  if (suggestion.title != null || suggestion.loss != null) {
    str += '**';
    if (suggestion.title != null) str += '${suggestion.title}'.trim();
    if (suggestion.loss != null) {
      str += ' (${suggestion.loss.toString()} points)';
    }
    str += '**: ';
  }
  ;
  str += suggestion.description.replaceAll(RegExp(r'(\n *)+'), '\n  * ');
  return str;
}

/// Process the output of the pana command and returns the [Result]
Result processOutput(Map<String, dynamic> output) {
  final dynamic scores = output['scores'];
  final String panaVersion = output['runtimeInfo']['panaVersion'];
  final double healthScore = scores['health'];
  final double maintenanceScore = scores['maintenance'];
  final List<Suggestion> generalSuggestions = <Suggestion>[];
  final List<Suggestion> maintenanceSuggestions = <Suggestion>[];
  final List<Suggestion> healthSuggestions = <Suggestion>[];
  final List<LineSuggestion> lineSuggestions = <LineSuggestion>[];

  final Map<String, void Function(List<Suggestion>)> categories = {
    'health': (suggestions) => healthSuggestions.addAll(suggestions),
    'maintenance': (suggestions) => maintenanceSuggestions.addAll(suggestions),
  };

  const String suggestionKey = 'suggestions';

  for (final String key in categories.keys) {
    if (output.containsKey(key)) {
      final Map<String, dynamic> category = output[key];
      if (category.containsKey(suggestionKey)) {
        categories[key](_parseSuggestions(category[suggestionKey]));
      }
    }
  }

  if (output.containsKey(suggestionKey)) {
    generalSuggestions.addAll(_parseSuggestions(output[suggestionKey]));
  }

  if (output.containsKey('dartFiles')) {
    final Map<String, dynamic> dartFiles = output['dartFiles'];
    for (final String file in dartFiles.keys) {
      final Map<String, dynamic> details = dartFiles[file];
      if (details.containsKey('codeProblems')) {
        final List<Map<String, dynamic>> problems =
            List.castFrom<dynamic, Map<String, dynamic>>(
                details['codeProblems']);
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
    generalSuggestions: generalSuggestions,
    maintenanceSuggestions: maintenanceSuggestions,
    healthSuggestions: healthSuggestions,
    lineSuggestions: lineSuggestions,
  );
}

List<Suggestion> _parseSuggestions(List<dynamic> list) =>
    List.castFrom<dynamic, Map<String, dynamic>>(list)
        .map((s) => Suggestion(
              description: s['description'],
              title: s['title'],
              loss: s['score'],
            ))
        .toList();
