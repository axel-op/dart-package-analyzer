import 'dart:convert';
import 'dart:io';

import 'package:app/github.dart';
import 'package:app/inputs.dart';
import 'package:app/pana.dart';
import 'package:app/result.dart';
import 'package:meta/meta.dart';
import 'package:pana/pana.dart';

const flutterPath = '/flutter/',
    dartPath = '/flutter/bin/cache/dart-sdk/'; // TODO pass as -d var

dynamic main(List<String> args) async {
  exitCode = 1;

  // Parsing user inputs and environment variables
  final Inputs inputs = Inputs();

  final Analysis analysis = await Analysis.queue(
    commitSha: inputs.commitSha,
    githubToken: inputs.githubToken,
    repositorySlug: inputs.repositorySlug,
    eventName: inputs.eventName,
  );

  Future<void> tryCancelAnalysis() async {
    try {
      await analysis.cancel();
    } catch (e, s) {
      _writeError(e, s);
    }
  }

  try {
    // Command to disable analytics reporting, and also to prevent a warning from the next command due to Flutter welcome screen
    await _runCommand('flutter', const <String>['config', '--no-analytics']);

    await analysis.start();

    // Executing the analysis
    stderr.writeln('Running analysis...');
    final Summary panaResult = await getSummary(
      packagePath: inputs.absolutePathToPackage,
      flutterPath: flutterPath,
      dartSdkDir: dartPath,
    );
    final Result result = Result.fromSummary(panaResult);

    // Posting comments on GitHub
    await analysis.complete(
      pathPrefix: inputs.filesPrefix,
      result: result,
      minAnnotationLevel: inputs.minAnnotationLevel,
      eventName: inputs.eventName,
    );

    exitCode = 0;
  } catch (e) {
    //_writeErrors(e, s); // useless if we rethrow it
    await tryCancelAnalysis();
    rethrow;
  }
}

/// Runs a command and prints its outputs to stderr and stdout while running.
/// Returns a [_ProcessResult] with the sdtout output in a String.
Future<_ProcessResult> _runCommand(
  String executable,
  List<String> arguments,
) async {
  final List<Future<dynamic>> streamsToFree = [];
  final Future<List<dynamic>> Function() freeStreams =
      () async => Future.wait<dynamic>(streamsToFree);
  try {
    final Process process =
        await Process.start(executable, arguments, runInShell: true);
    streamsToFree.add(stderr.addStream(process.stderr));
    final Stream<List<int>> outStream = process.stdout.asBroadcastStream();
    streamsToFree.add(stdout.addStream(outStream));
    final Future<List<String>> output =
        outStream.transform(utf8.decoder).toList();
    final int code = await process.exitCode;
    await freeStreams();
    return _ProcessResult(exitCode: code, output: (await output)?.join());
  } catch (e) {
    await freeStreams();
    rethrow;
  }
}

void _writeError(dynamic error, StackTrace stackTrace) {
  stderr.writeln(error.toString() +
      (stackTrace != null ? '\n' + stackTrace.toString() : ''));
}

class _ProcessResult {
  final String output;
  final int exitCode;

  _ProcessResult({
    @required this.exitCode,
    @required this.output,
  });
}
