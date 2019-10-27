import 'dart:convert';
import 'dart:io';

import 'package:app/github.dart';
import 'package:app/inputs.dart';
import 'package:app/result.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

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

  Future<void> _exitProgram([int code]) async {
    await tryCancelAnalysis();
    await Future.wait<dynamic>([stderr.done, stdout.done]);
    exit(code ?? exitCode);
  }

  try {
    final String flutterExecutable =
        path.canonicalize('${inputs.flutterPath}/bin/flutter');

    // Command to disable analytics reporting, and also to prevent a warning from the next command due to Flutter welcome screen
    await _runCommand(
      flutterExecutable,
      const <String>['config', '--no-analytics'],
    );

    // Installing pana package
    stderr.writeln('Activating pana package...');
    final int panaActivationExitCode = (await _runCommand(
      flutterExecutable,
      const <String>['pub', 'global', 'activate', 'pana', '^0.12.21'],
    ))
        .exitCode;

    if (panaActivationExitCode != 0) {
      await _exitProgram(panaActivationExitCode);
    }

    await analysis.start();

    // Executing the analysis
    stderr.writeln('Running analysis...');
    final _ProcessResult panaResult = await _runCommand(
      flutterExecutable,
      <String>[
        'pub',
        'global',
        'run',
        'pana',
        '--scores',
        '--no-warning',
        '--flutter-sdk',
        inputs.flutterPath,
        '--source',
        'path',
        inputs.absolutePathToPackage,
      ],
    );

    if (panaResult.exitCode != 0) {
      await _exitProgram(panaResult.exitCode);
    }
    if (panaResult.output == null) {
      throw Exception('The pana command has returned no valid output.');
    }

    final Map<String, dynamic> resultPana = jsonDecode(panaResult.output);
    final Result result = Result.fromOutput(resultPana);

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
