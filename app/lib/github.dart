import 'dart:io';
import 'dart:math';

import 'package:app/result.dart';
import 'package:github/server.dart';
import 'package:meta/meta.dart';

final bool testing = Platform.environment['TESTING'] == 'true';

class Analysis {
  final GitHub client;
  final CheckRun checkRun;
  final RepositorySlug repositorySlug;
  DateTime startTime;

  Analysis._({
    @required this.client,
    @required this.checkRun,
    @required this.repositorySlug,
  });

  static Future<Analysis> queue({
    @required String repositorySlug,
    @required String githubToken,
    @required String commitSha,
  }) async {
    final GitHub client = GitHub(auth: Authentication.withToken(githubToken));
    final RepositorySlug slug = RepositorySlug.full(repositorySlug);
    final CheckRun checkRun = await client.checks.createCheckRun(
      slug,
      status: CheckRunStatus.queued,
      name: 'Dart package analysis',
      headSha: commitSha,
    );
    return Analysis._(checkRun: checkRun, client: client, repositorySlug: slug);
  }

  Future<void> start() async {
    startTime = DateTime.now();
    await client.checks.updateCheckRun(
      repositorySlug,
      checkRun,
      startedAt: startTime,
      status: CheckRunStatus.inProgress,
    );
  }

  Future<void> cancel() async {
    await client.checks.updateCheckRun(
      repositorySlug,
      checkRun,
      startedAt: startTime,
      completedAt: DateTime.now(),
      status: CheckRunStatus.completed,
      conclusion: CheckRunConclusion.cancelled,
    );
  }

  Future<void> complete({
    @required Result result,
    @required String pathPrefix,
    @required CheckRunAnnotationLevel minAnnotationLevel,
  }) async {
    final List<CheckRunAnnotation> annotations = result.annotations
        .where((a) => a.level >= minAnnotationLevel)
        .map((a) => CheckRunAnnotation(
              annotationLevel: a.level,
              path: '$pathPrefix/${a.file}',
              title: a.errorType,
              message: '[${a.errorCode ?? ""}]\n${a.description}',
              startLine: a.line,
              endLine: a.line,
              startColumn: a.column,
              endColumn: a.column,
            ))
        .toList();
    final String title = 'Package analysis results for ${result.packageName}';
    final String summary = _buildSummary(result);
    final String text = _buildText(result);
    final CheckRunConclusion conclusion = testing
        ? CheckRunConclusion.neutral
        : result.annotations
                .where((a) => a.level == CheckRunAnnotationLevel.failure)
                .isNotEmpty
            ? CheckRunConclusion.failure
            : CheckRunConclusion.success;
    int i = 0;
    do {
      final bool isLastLoop = i + 50 >= annotations.length;
      await client.checks.updateCheckRun(
        repositorySlug,
        checkRun,
        name: 'Analysis of ${result.packageName}',
        status:
            isLastLoop ? CheckRunStatus.completed : CheckRunStatus.inProgress,
        startedAt: startTime,
        completedAt: isLastLoop ? DateTime.now() : null,
        conclusion: isLastLoop ? conclusion : null,
        output: CheckRunOutput(
          title: title,
          summary: summary,
          text: text,
          annotations: annotations.sublist(i, min(i + 50, annotations.length)),
        ),
      );
      i += 50;
    } while (i < annotations.length);
  }
}

String _buildSummary(Result result) {
  final String summary =
      '* Health score is **${result.healthScore.toString()} / 100.0**'
      '\n* Maintenance score is **${result.maintenanceScore.toString()} / 100.0**'
      '\n\n*Note that 50% of the overall score of your package on the [Pub site](https://pub.dev/help) will be based on its popularity ; 30% on its health score ; and 20% on its maintenance score.*';
  return (testing
          ? '**THIS ACTION HAS BEEN EXECUTED IN TEST MODE. THIS MODE IS NOT INTENDED FOR PRODUCTION USE.**\n'
          : '') +
      summary;
}

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
  return text +
      '\n### Versions'
          '\n* [Pana](https://pub.dev/packages/pana): ${result.panaVersion}'
          '\n* Dart: ${result.dartSdkVersion}'
          '\n* Flutter: ${result.flutterVersion}'; // with Dart ${result.dartSdkInFlutterVersion}'; // Useless as we use the Flutter command so this will be the same SDK
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
  return str + suggestion.description.replaceAll(RegExp(r'(\n *)+'), '\n  * ');
}
