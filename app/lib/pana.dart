import 'dart:io';

import 'package:meta/meta.dart';
import 'package:pana/pana.dart';

Future<Summary> getSummary({
  @required String flutterPath,
  @required String packagePath,
}) async {
  final tempPath = Directory.systemTemp
      .createTempSync('pana.${DateTime.now().millisecondsSinceEpoch}')
      .resolveSymbolicLinksSync();
  final analyzer = await PackageAnalyzer.create(
    flutterDir: flutterPath,
    pubCacheDir: tempPath,
  );
  final absolutePath = Directory(packagePath).resolveSymbolicLinksSync();
  final summary = await analyzer.inspectDir(absolutePath);
  return summary;
}
