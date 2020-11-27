/// A section of the report
class Section {
  final String title;
  final num grantedPoints;
  final num maxPoints;
  final String summary;
  final String id;
  final String status;

  /*
  const Section._(
    this.title,
    this.grantedPoints,
    this.maxPoints,
    this.summary,
  );
  */

  Section.fromJSON(Map<String, dynamic> json)
      : id = json['id'],
        status = json['status'],
        title = json['title'],
        grantedPoints = json['grantedPoints'] as int,
        maxPoints = json['maxPoints'] as int,
        summary = json['summary'];
}
