import 'package:app/annotation.dart';
import 'package:app/paths.dart';
import 'package:github/github.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

extension on Iterable<Annotation> {
  int count(CheckRunAnnotationLevel level) =>
      this.where((a) => a.level == level).length;
}

class AnalyzerResult {
  final int errorCount;
  final int warningCount;
  final int hintCount;
  final Set<Annotation> annotations;

  /// Name of the options file or package used
  final String options;

  const AnalyzerResult({
    @required this.errorCount,
    @required this.warningCount,
    @required this.hintCount,
    @required this.annotations,
    @required this.options,
  });

  factory AnalyzerResult.fromAnnotations(
    Iterable<Annotation> annotations, {
    @required String options,
  }) =>
      AnalyzerResult(
        errorCount: annotations.count(CheckRunAnnotationLevel.failure),
        warningCount: annotations.count(CheckRunAnnotationLevel.warning),
        hintCount: annotations.count(CheckRunAnnotationLevel.notice),
        annotations: annotations.toSet(),
        options: options,
      );

  factory AnalyzerResult.fromOutput(String output, {@required Paths paths}) =>
      AnalyzerResult.fromAnnotations(
        output
            .split('\n')
            .where((line) => line.isNotEmpty)
            .map((line) => Annotation.fromAnalyzer(line, paths: paths))
            .toList(),
        options:
            '`${path.relative(paths.canonicalPathToAnalysisOptions, from: paths.canonicalPathToRepoRoot)}`',
      );
}
