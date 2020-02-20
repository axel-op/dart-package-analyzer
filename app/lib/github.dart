import 'dart:io';

import 'package:app/analyzer_result.dart';
import 'package:app/annotation.dart';
import 'package:app/pana_result.dart';
import 'package:app/test_mode.dart';
import 'package:github/github.dart';
import 'package:meta/meta.dart';

extension on Annotation {
  CheckRunAnnotation toCheckRunAnnotation() => CheckRunAnnotation(
        annotationLevel: level,
        path: file,
        title: errorType,
        message: '[${errorCode ?? ""}]\n${description}',
        startLine: line,
        endLine: line,
        startColumn: column,
        endColumn: column,
      );
}

extension on Suggestion {
  String toItemString() {
    final str = StringBuffer('\n* ');
    if (title != null) {
      String trimmedTitle = title.trim();
      trimmedTitle = trimmedTitle.substring(
          0, trimmedTitle.length - (trimmedTitle.endsWith('.') ? 1 : 0));
      str.writeln('**$trimmedTitle**  ');
    }
    if (loss != null) {
      str.writeln('**$loss points**  ');
    }
    if (description != null) {
      str.write(description
          .trimRight()
          .replaceAll(RegExp(r'\n```'), '')
          .replaceAll(RegExp(r'(\n)+-? *'), '\n  * '));
    }
    return str.toString();
  }
}

extension on AnalyzerResult {
  CheckRunConclusion get conclusion =>
      annotations.any((a) => a.level == CheckRunAnnotationLevel.failure)
          ? CheckRunConclusion.failure
          : CheckRunConclusion.success;

  String get summary {
    final summary = StringBuffer('### Dartanalyzer');
    summary
      ..write('\n* Errors: **$errorCount**')
      ..write('\n* Warnings: **$warningCount**')
      ..write('\n* Hints: **$hintCount**');
    return summary.toString();
  }
}

extension on PanaResult {
  CheckRunConclusion get conclusion =>
      generalSuggestions.any((s) => s.description
              .toLowerCase()
              .contains("exception: couldn't find a pubspec"))
          ? CheckRunConclusion.failure
          : analyzerResult.conclusion;

  String get summary {
    final summary = StringBuffer()
      ..write('### Scores'
          '\n* Health score: **${healthScore.toStringAsFixed(2)}%**'
          '\n* Maintenance score: **${maintenanceScore.toStringAsFixed(2)}%**'
          '\n\n*Note that 50% of the overall score of your package on the [Pub site](https://pub.dev/help) will be based on its popularity ; 30% on its health score ; and 20% on its maintenance score.*');
    final platforms = supportedPlatforms;
    if (platforms.isNotEmpty) {
      summary.write('\n### Supported platforms');
    }
    for (final platform in supportedPlatforms.keys) {
      summary.write('\n* $platform');
      platforms[platform].forEach((tag) => summary.write('\n  * `$tag`'));
    }
    return summary.toString();
  }

  String get text {
    final Map<String, List<Suggestion>> suggestions = {
      'General': generalSuggestions,
      'Health': healthSuggestions,
      'Maintenance': maintenanceSuggestions,
    };
    final text = StringBuffer();
    if (suggestions.values.where((l) => l.isNotEmpty).isNotEmpty) {
      text.write('### Issues');
    }
    for (final MapEntry<String, List<Suggestion>> entry
        in suggestions.entries) {
      if (entry.value.isNotEmpty) {
        text.write('\n#### ${entry.key}');
        entry.value.forEach((s) => text.write(s.toItemString()));
      }
    }
    text.write('\n### Versions'
        '\n* [Pana](https://pub.dev/packages/pana): ${panaVersion}'
        '\n* Dart: ${dartSdkVersion}'
        '\n* Flutter: ${flutterVersion}');
    if (dartSdkVersion != dartSdkInFlutterVersion) {
      text.write(' with Dart ${dartSdkInFlutterVersion}');
    }
    return text.toString();
  }
}

class Analysis {
  static String _getCheckRunName({String packageName}) =>
      (packageName != null
          ? 'Analysis of $packageName'
          : 'Dart package analysis') +
      (testing ? ' (${Platform.environment['GITHUB_RUN_NUMBER']})' : '');

  static Future<Analysis> queue({
    @required String repositorySlug,
    @required String githubToken,
    @required String commitSha,
  }) async {
    final GitHub client = GitHub(auth: Authentication.withToken(githubToken));
    final RepositorySlug slug = RepositorySlug.full(repositorySlug);
    try {
      final CheckRun checkRun = await client.checks.checkRuns.createCheckRun(
        slug,
        status: CheckRunStatus.queued,
        name: _getCheckRunName(),
        headSha: commitSha,
      );
      return Analysis._(client, checkRun, slug);
    } catch (e) {
      if (e is GitHubError &&
          e.message.contains('Resource not accessible by integration')) {
        stderr.writeln('WARNING:'
            ' It seems that this action doesn\'t have the required permissions to call the GitHub API with the token you gave.'
            ' This can occur if this repository is a fork, as in that case GitHub reduces the GITHUB_TOKEN\'s permissions for security reasons.'
            ' Consequently, no report will be made on GitHub.'
            ' Check this issue for more information: '
            '\n* https://github.com/axel-op/dart-package-analyzer/issues/2');
        return Analysis._(client, null, slug);
      }
      rethrow;
    }
  }

  final GitHub _client;

  /// No report will be posted on GitHub if this is null.
  final CheckRun _checkRun;
  final RepositorySlug _repositorySlug;
  DateTime _startTime;

  Analysis._(
    this._client,
    this._checkRun,
    this._repositorySlug,
  );

  Future<void> start() async {
    if (_checkRun == null) return;
    _startTime = DateTime.now();
    await _client.checks.checkRuns.updateCheckRun(
      _repositorySlug,
      _checkRun,
      startedAt: _startTime,
      status: CheckRunStatus.inProgress,
    );
  }

  Future<void> cancel({dynamic cause}) async {
    if (_checkRun == null) return;
    await _client.checks.checkRuns.updateCheckRun(
      _repositorySlug,
      _checkRun,
      startedAt: _startTime,
      completedAt: DateTime.now(),
      status: CheckRunStatus.completed,
      conclusion: CheckRunConclusion.cancelled,
      output: cause == null
          ? null
          : CheckRunOutput(
              title: _getCheckRunName(),
              summary:
                  'This check run has been cancelled, due to the following error:'
                  '\n`$cause`'
                  '\nCheck your logs for more information.'),
    );
  }

  Future<void> complete({
    @required PanaResult panaResult,
    @required CheckRunAnnotationLevel minAnnotationLevel,
  }) async {
    final conclusion = panaResult.conclusion;
    if (_checkRun == null) {
      if (conclusion == CheckRunConclusion.failure) {
        stderr.writeAll(const <String>[
          'Static analysis has detected one or more compile-time errors.',
          'As no report can be posted, this action will directly fail.'
        ], " ");
        exitCode = 1;
      }
      return;
    }
    final List<CheckRunAnnotation> annotations = panaResult
        .analyzerResult.annotations
        .where((a) => a.level >= minAnnotationLevel)
        .map((a) => a.toCheckRunAnnotation())
        .toSet()
        .toList();
    final title = StringBuffer('Package analysis results');
    if (panaResult.packageName != null) {
      title.write(' for ${panaResult.packageName}');
    }
    final summary = StringBuffer();
    if (testing) {
      summary
        ..writeln('**THIS ACTION HAS BEEN EXECUTED IN TEST MODE.**')
        ..writeln('**Conclusion = `$conclusion`**');
    }
    summary
      ..writeln(panaResult.summary)
      ..write(panaResult.analyzerResult.summary);
    int i = 0;
    do {
      final isLastLoop = i + 50 >= annotations.length;
      await _client.checks.checkRuns.updateCheckRun(
        _repositorySlug,
        _checkRun,
        name: _getCheckRunName(packageName: panaResult.packageName),
        status:
            isLastLoop ? CheckRunStatus.completed : CheckRunStatus.inProgress,
        startedAt: _startTime,
        completedAt: isLastLoop ? DateTime.now() : null,
        conclusion: isLastLoop
            ? (testing ? CheckRunConclusion.neutral : conclusion)
            : null,
        output: CheckRunOutput(
          title: title.toString(),
          summary: summary.toString(),
          text: panaResult.text,
          annotations:
              annotations.sublist(i, isLastLoop ? annotations.length : i + 50),
        ),
      );
      i += 50;
    } while (i < annotations.length);
  }
}
