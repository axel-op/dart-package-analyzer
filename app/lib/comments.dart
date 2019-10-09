import 'package:app/result.dart';
import 'package:meta/meta.dart';

class Comment {
  final String body;
  final String file;
  final int lineInFile;

  Comment._({
    @required this.body,
    this.file,
    this.lineInFile,
  });

  static List<Comment> fromResult(
    Result result, {
    @required String pathPrefix,
    @required String commitSha,
  }) =>
      [
        Comment._(
            body: _buildGeneralComment(result: result, commitSha: commitSha))
      ]..addAll(result.lineSuggestions
          .map((s) => Comment._fromLineSuggestion(s, pathPrefix: pathPrefix)));

  factory Comment._fromLineSuggestion(
    LineSuggestion suggestion, {
    @required String pathPrefix,
  }) =>
      Comment._(
        body: suggestion.description,
        file: '$pathPrefix/${suggestion.file}',
        lineInFile: suggestion.line,
      );
}

/// Builds the message to be posted on GitHub
String _buildGeneralComment({
  @required final Result result,
  @required final String commitSha,
}) {
  final Map<String, List<Suggestion>> suggestions = {
    'General': result.generalSuggestions,
    'Health': result.healthSuggestions,
    'Maintenance': result.maintenanceSuggestions,
  };

  String comment = '## Package analysis results for commit $commitSha'
      '\n(version of [pana](https://pub.dev/packages/pana) used: ${result.panaVersion})'
      '\n\n* Health score is **${result.healthScore.toString()} / 100.0**'
      '\n* Maintenance score is **${result.maintenanceScore.toString()} / 100.0**'
      '\n\n*Please note that 50% of the overall score of your package on the [Pub site](https://pub.dev/help) will be based on its popularity ; 30% on its health score ; and 20% on its maintenance score.*';
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
    if (suggestion.title != null) {
      final String trimmedTitle = suggestion.title.trim();
      str += trimmedTitle.substring(
          0, trimmedTitle.length - (trimmedTitle.endsWith('.') ? 1 : 0));
    }
    if (suggestion.loss != null) {
      str += ' (${suggestion.loss.toString()} points)';
    }
    str += '**: ';
  }
  ;
  str += suggestion.description.replaceAll(RegExp(r'(\n *)+'), '\n  * ');
  return str;
}
