import 'package:app/analyzer_result.dart';
import 'package:app/annotation.dart';
import 'package:app/extensions/map.dart';
import 'package:app/paths.dart';
import 'package:meta/meta.dart';

class Suggestion {
  final double loss;
  final String description;
  final String title;

  Suggestion._fromJSON(Map<String, dynamic> json)
      : description = json['description'],
        loss = json['score'],
        title = json['title'];
}

class PanaResult {
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
  final Map<String, List<String>> supportedPlatforms;
  final AnalyzerResult analyzerResult;

  PanaResult._({
    @required this.packageName,
    @required this.healthScore,
    @required this.maintenanceScore,
    @required this.panaVersion,
    @required this.generalSuggestions,
    @required this.healthSuggestions,
    @required this.maintenanceSuggestions,
    @required this.dartSdkInFlutterVersion,
    @required this.dartSdkVersion,
    @required this.flutterVersion,
    @required this.supportedPlatforms,
    @required this.analyzerResult,
  });

  factory PanaResult.fromOutput(
    Map<String, dynamic> output, {
    @required Paths paths,
  }) {
    final String packageName = output['packageName'];
    final Map<String, dynamic> runtimeInfo = output['runtimeInfo'];
    final String panaVersion = runtimeInfo['panaVersion'];
    final String dartSdkVersion = runtimeInfo['sdkVersion'];
    final Map<String, dynamic> flutterInfo = runtimeInfo['flutterVersions'];
    final String flutterVersion = flutterInfo['frameworkVersion'];
    final String dartInFlutterVersion = flutterInfo['dartSdkVersion'];
    final Map<String, dynamic> scores = output['scores'];
    final double healthScore = scores['health'];
    final double maintenanceScore = scores['maintenance'];
    final List<Suggestion> generalSuggestions = [];
    final List<Suggestion> maintenanceSuggestions = [];
    final List<Suggestion> healthSuggestions = [];
    final List<Annotation> lineSuggestions = [];
    final Map<String, List<String>> supportedPlatforms = {};

    final Map<String, void Function(List<Suggestion>)> categories = {
      'health': (suggestions) => healthSuggestions.addAll(suggestions),
      'maintenance': (suggestions) =>
          maintenanceSuggestions.addAll(suggestions),
    };

    const String suggestionKey = 'suggestions';

    List<Suggestion> parseSuggestions(List<dynamic> list) =>
        List.castFrom<dynamic, Map<String, dynamic>>(list)
            .map((s) => Suggestion._fromJSON(s))
            .toList();

    for (final String key in categories.keys) {
      if (output.containsKey(key)) {
        final Map<String, dynamic> category = output[key];
        if (category.containsKey(suggestionKey)) {
          categories[key](parseSuggestions(category[suggestionKey]));
        }
      }
    }

    if (output.containsKey(suggestionKey)) {
      generalSuggestions.addAll(parseSuggestions(output[suggestionKey]));
    }

    final Map<String, dynamic> dartFiles = output['dartFiles'];
    if (dartFiles != null) {
      for (final file in dartFiles.keys) {
        final Map<String, dynamic> details = dartFiles[file];
        if (details.containsNonNull('codeProblems')) {
          final List<Map<String, dynamic>> problems =
              List.castFrom<dynamic, Map<String, dynamic>>(
                  details['codeProblems']);
          lineSuggestions.addAll(problems.map(
            (jsonObj) => Annotation.fromPana(jsonObj, paths: paths),
          ));
        }
      }
    }

    final List<dynamic> tags = output['tags'];
    if (tags != null) {
      List.castFrom<dynamic, String>(tags).forEach((tag) {
        final splitted = tag.split(":");
        if (splitted.length != 2) return;
        switch (splitted[0]) {
          case 'platform':
            supportedPlatforms
                .putIfAbsent('Flutter', () => [])
                .add(splitted[1]);
            break;
          case 'runtime':
            supportedPlatforms.putIfAbsent('Dart', () => []).add(splitted[1]);
            break;
        }
      });
    }

    return PanaResult._(
      packageName: packageName,
      panaVersion: panaVersion,
      maintenanceScore: maintenanceScore,
      healthScore: healthScore,
      generalSuggestions: generalSuggestions,
      healthSuggestions: healthSuggestions,
      maintenanceSuggestions: maintenanceSuggestions,
      flutterVersion: flutterVersion,
      dartSdkInFlutterVersion: dartInFlutterVersion,
      dartSdkVersion: dartSdkVersion,
      supportedPlatforms: supportedPlatforms,
      analyzerResult: AnalyzerResult.fromAnnotations(
        lineSuggestions,
        options: '[`pedantic`](https://pub.dev/packages/pedantic)',
      ),
    );
  }
}
