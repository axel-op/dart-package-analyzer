import 'package:meta/meta.dart';

class Result {
  double health_score;
  double maintenance_score;
  String pana_version;

  List<Suggestion> _maintenance_suggestions = [];
  List<Suggestion> _health_suggestions = [];

  Result(
      {@required this.health_score,
      @required this.maintenance_score,
      @required this.pana_version});

  List<Suggestion> get maintenance_suggestions =>
      _maintenance_suggestions.toList();
  List<Suggestion> get health_suggestions => _health_suggestions.toList();

  void addHealthSuggestion(Suggestion suggestion) =>
      _health_suggestions.add(suggestion);
  void addMaintenanceSuggestion(Suggestion suggestion) =>
      _maintenance_suggestions.add(suggestion);
}

class Suggestion {
  final double loss;
  final String description;
  final String title;

  Suggestion({this.loss, @required this.description, @required this.title});
}
