import 'dart:math';

import 'package:app/result.dart';
import 'package:github/server.dart';
import 'package:meta/meta.dart';

//final bool testing = Platform.environment['TESTING'] == 'true';

const Map<AnnotationLevel, CheckRunAnnotationLevel> _annotationsMapping = {
  AnnotationLevel.Error: CheckRunAnnotationLevel.failure,
  AnnotationLevel.Warning: CheckRunAnnotationLevel.warning,
  AnnotationLevel.Info: CheckRunAnnotationLevel.notice,
};

GitHub _client;

GitHub _getClient(String token) {
  _client ??= createGitHubClient(auth: Authentication.withToken(token));
  return _client;
}

Future<CheckRun> startAnalysis({
  @required String repositorySlug,
  @required String commitSha,
  @required String githubToken,
  @required Future<void> Function(dynamic, dynamic) onError,
}) async {
  final GitHub client = _getClient(githubToken);
  final RepositorySlug slug = RepositorySlug.full(repositorySlug);
  try {
    return client.checks.createCheckRun(
      slug,
      name: 'Dart package analysis',
      headSha: commitSha,
      startedAt: DateTime.now(),
      status: CheckRunStatus.inProgress,
    );
  } catch (e, s) {
    await onError(e, s);
  }
  return null;
}

Future<void> cancelAnalysis({
  @required String repositorySlug,
  @required CheckRun checkRun,
  @required String githubToken,
  @required Future<void> Function(dynamic, dynamic) onError,
}) async {
  try {
    final GitHub client = _getClient(githubToken);
    final RepositorySlug slug = RepositorySlug.full(repositorySlug);
    await client.checks.updateCheckRun(
      slug,
      checkRun,
      completedAt: DateTime.now(),
      status: CheckRunStatus.completed,
      conclusion: CheckRunConclusion.cancelled,
    );
  } catch (e, s) {
    await onError(e, s);
  }
}

Future<void> postResultsAndEndAnalysis({
  @required String repositorySlug,
  @required String githubToken,
  @required CheckRun checkRun,
  @required Result result,
  @required String pathPrefix,
  @required AnnotationLevel minAnnotationLevel,
  @required Future<void> Function(dynamic error, dynamic stack) onError,
}) async {
  final List<CheckRunAnnotation> annotations = result.annotations
      .where((a) {
        switch (a.level) {
          case AnnotationLevel.Info:
            return minAnnotationLevel == AnnotationLevel.Info;
          case AnnotationLevel.Warning:
            return minAnnotationLevel != AnnotationLevel.Error;
          default:
            return true;
        }
      })
      .map((a) => CheckRunAnnotation(
            annotationLevel: _annotationsMapping[a.level],
            path: '$pathPrefix/${a.file}',
            title: a.errorType,
            message: '[${a.errorCode ?? ""}] ${a.description}',
            startLine: a.line,
            endLine: a.line,
            startColumn: a.column,
            endColumn: a.column,
          ))
      .toList();
  final GitHub client = _getClient(githubToken);
  final RepositorySlug repoSlug = RepositorySlug.full(repositorySlug);
  final String title = 'Package analysis results for ${result.packageName}';
  final String summary = _buildSummary(result);
  final String text = _buildText(result);
  final CheckRunConclusion conclusion = result.annotations
          .where((a) => a.level == AnnotationLevel.Error)
          .isNotEmpty
      ? CheckRunConclusion.failure
      : CheckRunConclusion.success;
  int i = 0;
  do {
    final bool isLastLoop = i + 50 >= annotations.length;
    try {
      await client.checks.updateCheckRun(
        repoSlug,
        checkRun,
        name: 'Analysis of ${result.packageName}',
        status:
            isLastLoop ? CheckRunStatus.completed : CheckRunStatus.inProgress,
        completedAt: isLastLoop ? DateTime.now() : null,
        conclusion: isLastLoop ? conclusion : null,
        output: CheckRunOutput(
          title: title,
          summary: summary,
          text: text,
          annotations: annotations.sublist(i, min(i + 50, annotations.length)),
        ),
      );
    } catch (e, s) {
      await onError(e, s);
    }
    i += 50;
  } while (i < annotations.length);
}

String _buildSummary(Result result) =>
    '* Health score is **${result.healthScore.toString()} / 100.0**'
    '\n* Maintenance score is **${result.maintenanceScore.toString()} / 100.0**'
    '\n\n*Note that 50% of the overall score of your package on the [Pub site](https://pub.dev/help) will be based on its popularity ; 30% on its health score ; and 20% on its maintenance score.*';

String _buildText(Result result) {
  final Map<String, List<Suggestion>> suggestions = {
    'General': result.generalSuggestions,
    'Health': result.healthSuggestions,
    'Maintenance': result.maintenanceSuggestions,
  };
  String text = '';
  if (suggestions.values.where((l) => l.isNotEmpty).isNotEmpty) {
    text += '### Issues';
  }
  for (final MapEntry<String, List<Suggestion>> entry in suggestions.entries) {
    if (entry.value.isNotEmpty) {
      text += '\n#### ${entry.key}';
      entry.value.forEach((s) => text += _stringSuggestion(s));
    }
  }
  text += '\n### Versions'
      '\n* [Pana](https://pub.dev/packages/pana): ${result.panaVersion}'
      '\n* Dart: ${result.dartSdkVersion}'
      '\n* Flutter: ${result.flutterVersion} with Dart ${result.dartSdkInFlutterVersion}';
  return text;
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
