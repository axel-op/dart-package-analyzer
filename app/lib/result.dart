import 'package:github/server.dart';
import 'package:meta/meta.dart';

const Map<String, CheckRunAnnotationLevel> _annotationLevels = {
  'ERROR': CheckRunAnnotationLevel.failure,
  'WARNING': CheckRunAnnotationLevel.warning,
  'INFO': CheckRunAnnotationLevel.notice,
};

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

  factory Annotation._fromJSON(Map<String, dynamic> json) => Annotation._(
        description: json['description'],
        line: json['line'],
        file: json['file'],
        column: json['col'],
        level: _annotationLevels[json['severity']],
        errorCode: json['errorCode'],
        errorType: json['errorType'],
      );
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
  });

  factory Result.fromOutput(Map<String, dynamic> output) {
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
    final List<Suggestion> generalSuggestions = <Suggestion>[];
    final List<Suggestion> maintenanceSuggestions = <Suggestion>[];
    final List<Suggestion> healthSuggestions = <Suggestion>[];
    final List<Annotation> lineSuggestions = <Annotation>[];

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

    if (output.containsKey('dartFiles')) {
      final Map<String, dynamic> dartFiles = output['dartFiles'];
      for (final String file in dartFiles.keys) {
        final Map<String, dynamic> details = dartFiles[file];
        if (details.containsKey('codeProblems')) {
          final List<Map<String, dynamic>> problems =
              List.castFrom<dynamic, Map<String, dynamic>>(
                  details['codeProblems']);
          lineSuggestions.addAll(problems.map(
            (jsonObj) => Annotation._fromJSON(jsonObj),
          ));
        }
      }
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
    );
  }
}
