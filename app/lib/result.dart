import 'package:meta/meta.dart';

class Result {
  final double healthScore;
  final double maintenanceScore;
  final String panaVersion;
  final String flutterVersion;
  final String dartSdkVersion;
  final String dartSdkInFlutterVersion;
  final List<Suggestion> generalSuggestions;
  final List<Suggestion> healthSuggestions;
  final List<Suggestion> maintenanceSuggestions;
  final List<LineSuggestion> lineSuggestions;

  Result._({
    @required this.healthScore,
    @required this.maintenanceScore,
    @required this.panaVersion,
    @required this.generalSuggestions,
    @required this.healthSuggestions,
    @required this.maintenanceSuggestions,
    @required this.lineSuggestions,
    @required this.dartSdkInFlutterVersion,
    @required this.dartSdkVersion,
    @required this.flutterVersion,
  });

  factory Result.fromOutput(Map<String, dynamic> output) =>
      _processOutput(output);
}

class Suggestion {
  final double loss;
  final String description;
  final String title;

  Suggestion._({
    @required this.description,
    @required this.loss,
    @required this.title,
  });

  factory Suggestion._fromJSON(Map<String, dynamic> json) => Suggestion._(
        description: json['description'],
        loss: json['score'],
        title: json['title'],
      );
}

class LineSuggestion extends Suggestion {
  final String file;
  final int line;

  LineSuggestion._({
    @required String description,
    @required this.file,
    @required this.line,
  }) : super._(
          description: description,
          loss: null,
          title: null,
        );

  factory LineSuggestion._fromJSON(Map<String, dynamic> json) =>
      LineSuggestion._(
        description: json['description'],
        line: json['line'],
        file: json['file'],
      );
}

/// Processes the output of pana command and returns the [Result]
Result _processOutput(Map<String, dynamic> output) {
  final dynamic scores = output['scores'];
  final Map<String, dynamic> runtimeInfo = output['runtimeInfo'];
  final String panaVersion = runtimeInfo['panaVersion'];
  final String dartSdkVersion = runtimeInfo['sdkVersion'];
  final Map<String, dynamic> flutterInfo = runtimeInfo['flutterVersions'];
  final String flutterVersion = flutterInfo['frameworkVersion'];
  final String dartInFlutterVersion = flutterInfo['dartSdkVersion'];
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
        lineSuggestions.addAll(problems.map(
          (jsonObj) => LineSuggestion._fromJSON(jsonObj),
        ));
      }
    }
  }

  return Result._(
    panaVersion: panaVersion,
    maintenanceScore: maintenanceScore,
    healthScore: healthScore,
    generalSuggestions: generalSuggestions,
    healthSuggestions: healthSuggestions,
    maintenanceSuggestions: maintenanceSuggestions,
    lineSuggestions: lineSuggestions,
    flutterVersion: flutterVersion,
    dartSdkInFlutterVersion: dartInFlutterVersion,
    dartSdkVersion: dartSdkVersion,
  );
}

List<Suggestion> _parseSuggestions(List<dynamic> list) =>
    List.castFrom<dynamic, Map<String, dynamic>>(list)
        .map((s) => Suggestion._fromJSON(s))
        .toList();
