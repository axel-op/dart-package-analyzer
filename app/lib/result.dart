import 'package:meta/meta.dart';

class Result {
  final double healthScore;
  final double maintenanceScore;
  final String panaVersion;
  final List<Suggestion> generalSuggestions;
  final List<Suggestion> maintenanceSuggestions;
  final List<Suggestion> healthSuggestions;
  final List<LineSuggestion> lineSuggestions;

  Result({
    @required this.healthScore,
    @required this.maintenanceScore,
    @required this.panaVersion,
    @required this.generalSuggestions,
    @required this.maintenanceSuggestions,
    @required this.healthSuggestions,
    @required this.lineSuggestions,
  })  : assert(generalSuggestions != null),
        assert(maintenanceSuggestions != null),
        assert(healthSuggestions != null),
        assert(lineSuggestions != null);
}

class Suggestion {
  final double loss;
  final String description;
  final String title;

  Suggestion({this.loss, @required this.description, this.title});
}

class LineSuggestion extends Suggestion {
  final int lineNumber;
  final String relativePath;

  LineSuggestion(
      {@required String description,
      @required this.lineNumber,
      @required this.relativePath})
      : super(description: description);
}
