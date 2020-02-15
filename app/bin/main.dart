import 'dart:convert';
import 'dart:io';

import 'package:app/github.dart';
import 'package:app/inputs.dart';
import 'package:app/result.dart';
import 'package:meta/meta.dart';

dynamic main(List<String> args) async {
  exitCode = 0;

  // Parsing user inputs and environment variables
  final Inputs _inputs = Inputs();

  final Analysis _analysis = await Analysis.queue(
    commitSha: _inputs.commitSha,
    githubToken: _inputs.githubToken,
    repositorySlug: _inputs.repositorySlug,
  );

  Future<void> _tryCancelAnalysis(dynamic cause) async {
    try {
      await _analysis.cancel(cause: cause);
    } catch (e, s) {
      _writeError(e, s);
    }
  }

  Future<void> _exitProgram([dynamic cause]) async {
    await _tryCancelAnalysis(cause);
    await Future.wait<dynamic>([stderr.done, stdout.done]);
    stderr.writeln('Exiting with code $exitCode');
    exit(exitCode);
  }

  try {
    // Command to disable analytics reporting, and also to prevent a warning from the next command due to Flutter welcome screen
    await _runCommand('flutter', const <String>['config', '--no-analytics']);

    await _analysis.start();

    // Executing the analysis
    stderr.writeln('Running analysis...');
    final _ProcessResult panaResult = await _runCommand(
      'pana',
      <String>[
        '--scores',
        '--no-warning',
        '--source',
        'path',
        _inputs.absolutePathToPackage,
      ],
    );

    if (panaResult.exitCode != 0) {
      stderr.writeln('Pana exited with code ${panaResult.exitCode}');
      exitCode = panaResult.exitCode;
      await _exitProgram();
    }
    if (panaResult.output == null) {
      throw Exception('The pana command has returned no valid output.'
          ' This should never happen.'
          ' Please file an issue at https://github.com/axel-op/dart-package-analyzer/issues/new');
    }

    final Result result = Result.fromOutput(
      jsonDecode(panaResult.output) as Map<String, dynamic>,
      filesPrefix: _inputs.pathFromRepoRoot,
    );

    // Posting comments on GitHub
    await _analysis.complete(
      result: result,
      minAnnotationLevel: _inputs.minAnnotationLevel,
    );

    // Setting outputs
    await _setOutput('maintenance', result.maintenanceScore.toStringAsFixed(2));
    await _setOutput('health', result.healthScore.toStringAsFixed(2));
  } catch (e) {
    //_writeErrors(e, s); // useless if we rethrow it
    await _tryCancelAnalysis(e);
    rethrow;
  }
}

/// Set an output for this Action.
/// This output will be available for subsequent steps in the workflow.
Future<void> _setOutput(String key, String value) async {
  await _runCommand('echo', ['::set-output name=$key::$value']);
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
