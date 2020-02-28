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
  final Map<String, List<String>> supportedPlatforms;

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
    @required this.supportedPlatforms,
  });

  factory Result.fromOutput(
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

    return Result._(
      packageName: packageName,
      panaVersion: panaVersion,
      maintenanceScore: maintenanceScore,
      healthScore: healthScore,
      generalSuggestions: generalSuggestions,
      healthSuggestions: healthSuggestions,
      maintenanceSuggestions: maintenanceSuggestions,
      annotations: lineSuggestions,
      flutterVersion: flutterVersion,
      dartSdkInFlutterVersion: dartInFlutterVersion,
      dartSdkVersion: dartSdkVersion,
      supportedPlatforms: supportedPlatforms,
    );
  }
}
