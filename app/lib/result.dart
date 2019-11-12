import 'dart:io';
import 'dart:math';

import 'package:github/github.dart';
import 'package:meta/meta.dart';
import 'package:pana/pana.dart';

final bool testing = Platform.environment['INPUT_TESTING'] == 'true';

class Annotation {
  final String file;
  final int line;
  final int column;
  final String description;
  final CheckRunAnnotationLevel level;
  final String errorType;
  final String errorCode;

  Annotation._({
    @required this.description,
    @required this.file,
    @required this.line,
    @required this.column,
    @required this.level,
    @required this.errorCode,
    @required this.errorType,
  });
}

class Result {
  final String packageName;
  final double healthScore;
  final double maintenanceScore;
  final String panaVersion;
  final String flutterVersion;
  final String dartSdkVersion;
  final String dartSdkInFlutterVersion;
  final List<Suggestion> generalSuggestions;
  final List<Suggestion> healthSuggestions;
  final List<Suggestion> maintenanceSuggestions;
  final List<Annotation> annotations;

  static double _calculateScore(List<Suggestion> suggestions) {
    if (suggestions == null || suggestions.isEmpty) {
      return 0.0;
    }
    final score = max(0.0,
        suggestions?.fold<double>(100.0, (d, s) => d - (s.score ?? 0)) ?? 0.0);
    return (score * 100.0).round() / 100.0;
  }

  Result._({
    @required this.packageName,
    @required this.healthScore,
    @required this.maintenanceScore,
    @required this.panaVersion,
    @required this.generalSuggestions,
    @required this.healthSuggestions,
    @required this.maintenanceSuggestions,
    @required this.annotations,
    @required this.dartSdkInFlutterVersion,
    @required this.dartSdkVersion,
    @required this.flutterVersion,
  }) {
    if (testing) {
      [
        packageName,
        healthScore,
        maintenanceScore,
        panaVersion,
        healthSuggestions,
        maintenanceSuggestions,
        annotations,
        dartSdkInFlutterVersion,
        dartSdkVersion,
        dartSdkInFlutterVersion,
      ].forEach(ArgumentError.checkNotNull);
    }
  }

  factory Result.fromSummary(Summary summary) {
    final Map<String, dynamic> flutterInfo =
        summary.runtimeInfo.flutterVersions;

    final List<Annotation> annotations = [];
    summary.dartFiles?.forEach((file, DartFileSummary details) {
      details.codeProblems?.forEach((CodeProblem p) {
        final level = p.isError
            ? CheckRunAnnotationLevel.failure
            : p.isWarning
                ? CheckRunAnnotationLevel.warning
                : CheckRunAnnotationLevel.notice;
        annotations.add(Annotation._(
          file: p.file,
          level: level,
          errorType: p.errorType,
          errorCode: p.errorCode,
          line: p.line,
          column: p.col,
          description: p.description,
        ));
      });
    });

    return Result._(
      packageName: summary.packageName,
      panaVersion: summary.runtimeInfo.panaVersion,
      dartSdkVersion: summary.runtimeInfo.sdkVersion,
      flutterVersion: flutterInfo['frameworkVersion'],
      dartSdkInFlutterVersion: flutterInfo['dartSdkVersion'],
      healthScore: _calculateScore(summary.health.suggestions),
      maintenanceScore: _calculateScore(summary.maintenance.suggestions),
      annotations: annotations,
      generalSuggestions: summary.suggestions ?? [],
      healthSuggestions: summary.health.suggestions ?? [],
      maintenanceSuggestions: summary.maintenance.suggestions ?? [],
    );
  }
}
