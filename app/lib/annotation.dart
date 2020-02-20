import 'package:app/paths.dart';
import 'package:app/extensions/map.dart';
import 'package:github/github.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:app/test_mode.dart';

const Map<String, CheckRunAnnotationLevel> _annotationLevels = {
  'ERROR': CheckRunAnnotationLevel.failure,
  'WARNING': CheckRunAnnotationLevel.warning,
  'INFO': CheckRunAnnotationLevel.notice,
};

class Annotation {
  final String file;
  final int line;
  final int column;
  final String description;
  final CheckRunAnnotationLevel level;
  final String errorType;
  final String errorCode;

  Annotation._({
    @required this.file,
    @required this.level,
    @required this.errorType,
    @required this.errorCode,
    @required this.line,
    @required this.column,
    @required this.description,
  }) {
    assertion(level != null);
    assertion(file != null);
    assertion(line != null);
  }

  @override
  bool operator ==(dynamic other) {
    if (other is Annotation) {
      return other.file == file &&
          other.level == level &&
          other.errorType == errorType &&
          other.errorCode == errorCode &&
          other.line == line &&
          other.column == column &&
          other.description == description;
    }
    return false;
  }

  @override
  int get hashCode => file.hashCode;

  factory Annotation.fromPana(
    Map<String, dynamic> json, {
    @required Paths paths,
  }) =>
      Annotation._(
          file: json.containsNonNull('file')
              ? path.normalize(
                  "${path.relative(paths.canonicalPathToPackage, from: paths.canonicalPathToRepoRoot)}/${json['file']}")
              : null,
          level: _annotationLevels[json['severity']],
          errorType: json['errorType'],
          errorCode: json['errorCode'],
          line: json['line'],
          column: json['col'],
          description: json['description']);

  factory Annotation.fromAnalyzer(
    String line, {
    @required Paths paths,
  }) {
    log('line: $line');
    final elements = line.split('|');
    final fullPath = elements[3];
    return Annotation._(
      file: path.relative(fullPath, from: paths.canonicalPathToRepoRoot),
      level: _annotationLevels[elements[0]],
      errorType: elements[1],
      errorCode: elements[2],
      line: int.tryParse(elements[4]),
      column: int.tryParse(elements[5]),
      description: elements[7],
    );
  }
}
