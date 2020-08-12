/// A section of the report
class Section {
  final String title;
  final num grantedPoints;
  final num maxPoints;
  final String summary;

  const Section._(
    this.title,
    this.grantedPoints,
    this.maxPoints,
    this.summary,
  );

  Section.fromJSON(Map<String, dynamic> json)
      : title = json['title'],
        grantedPoints = (json['grantedPoints'] as int).toDouble(),
        maxPoints = (json['maxPoints'] as int).toDouble(),
        summary = json['summary'];
}
