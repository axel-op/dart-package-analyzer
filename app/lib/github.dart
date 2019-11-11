import 'dart:io';

import 'package:app/result.dart';
import 'package:github/github.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

final bool testing = Platform.environment['INPUT_TESTING'] == 'true';

class Analysis {
  static String _getCheckRunName({
    @required String eventName,
    String packageName,
  }) =>
      (packageName != null
          ? 'Analysis of $packageName'
          : 'Dart package analysis') +
      ' ($eventName)';

  static Future<Analysis> queue({
    @required String repositorySlug,
    @required String githubToken,
    @required String commitSha,
    @required String eventName,
  }) async {
    final GitHub client = GitHub(auth: Authentication.withToken(githubToken));
    final RepositorySlug slug = RepositorySlug.full(repositorySlug);
    try {
      final CheckRun checkRun = await client.checks.createCheckRun(
        slug,
        status: CheckRunStatus.queued,
        name: _getCheckRunName(eventName: eventName),
        headSha: commitSha,
      );
      return Analysis._(client, checkRun, slug);
    } catch (e) {
      if (e is GitHubError &&
          e.message.contains('Resource not accessible by integration')) {
        stderr.writeln(
            'It seems that this action doesn\'t have the required permissions to call the GitHub API with the token you gave.'
            'If you\'re using the default GITHUB_TOKEN, this may be because this repository is a fork and the workflow file by which this action is triggered has been edited.'
            'In that case, GitHub reduces the token\'s permissions for security reasons.'
            'This action thus should work once the workflow file has been merged to the original repository.');
      }
      rethrow;
    }
  }

  final GitHub _client;
  final CheckRun _checkRun;
  final RepositorySlug _repositorySlug;
  DateTime _startTime;

  Analysis._(
    this._client,
    this._checkRun,
    this._repositorySlug,
  );

  Future<void> start() async {
    _startTime = DateTime.now();
    await _client.checks.updateCheckRun(
      _repositorySlug,
      _checkRun,
      startedAt: _startTime,
      status: CheckRunStatus.inProgress,
    );
  }

  Future<void> cancel() async {
    await _client.checks.updateCheckRun(
      _repositorySlug,
      _checkRun,
      startedAt: _startTime,
      completedAt: DateTime.now(),
      status: CheckRunStatus.completed,
      conclusion: CheckRunConclusion.cancelled,
    );
  }

  Future<void> complete({
    @required Result result,
    @required String eventName,
    @required String pathPrefix,
    @required CheckRunAnnotationLevel minAnnotationLevel,
  }) async {
    final List<CheckRunAnnotation> annotations = result.annotations
        .where((a) => a.level >= minAnnotationLevel)
        .map((a) => CheckRunAnnotation(
              annotationLevel: a.level,
              path: path.normalize('$pathPrefix/${a.file}'),
              title: a.errorType,
              message: '[${a.errorCode ?? ""}]\n${a.description}',
              startLine: a.line,
              endLine: a.line,
              startColumn: a.column,
              endColumn: a.column,
            ))
        .toList();
    final String title = result.packageName != null
        ? 'Package analysis results for ${result.packageName}'
        : 'Package analysis results';
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
      await _client.checks.updateCheckRun(
        _repositorySlug,
        _checkRun,
        name: _getCheckRunName(
          eventName: eventName,
          packageName: result.packageName,
        ),
        status:
            isLastLoop ? CheckRunStatus.completed : CheckRunStatus.inProgress,
        startedAt: _startTime,
        completedAt: isLastLoop ? DateTime.now() : null,
        conclusion: isLastLoop ? conclusion : null,
        output: CheckRunOutput(
          title: title,
          summary: summary,
          text: text,
          annotations:
              annotations.sublist(i, isLastLoop ? annotations.length : i + 50),
        ),
      );
      i += 50;
    } while (i < annotations.length);
  }
}

String _buildSummary(Result result) =>
    (testing
        ? '**THIS ACTION HAS BEEN EXECUTED IN TEST MODE. THIS MODE IS NOT INTENDED FOR PRODUCTION USE.**\n'
        : '') +
    '* Health score: **${result.healthScore.toStringAsFixed(2)}%**'
        '\n* Maintenance score: **${result.maintenanceScore.toStringAsFixed(2)}%**'
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
  return str +
      (suggestion.description
              ?.trimRight()
              ?.replaceAll(RegExp(r'\n```'), '')
              ?.replaceAll(RegExp(r'(\n)+-? *'), '\n  * ') ??
          '');
}
