import 'dart:convert';
import 'dart:io';

import 'package:app/github.dart';
import 'package:app/inputs.dart';
import 'package:app/result.dart';
import 'package:meta/meta.dart';
import 'package:pedantic/pedantic.dart';

dynamic main(List<String> args) async {
  exitCode = 1;

  // Parsing command arguments
  final Inputs inputs = await getInputs();

  // Displaying commit SHA
  stderr.writeln('This action will be run for commit ${inputs.commitSha}');

  final Analysis analysis = await Analysis.queue(
    commitSha: inputs.commitSha,
    githubToken: inputs.githubToken,
    repositorySlug: inputs.repositorySlug,
  );

  void tryCancelAnalysis() {
    try {
      analysis.cancel();
    } catch (e, s) {
      _writeErrors(e, s);
    }
  }

  Future<void> _exitProgram([int code]) async {
    tryCancelAnalysis();
    await Future.wait<dynamic>([stderr.done, stdout.done]);
    exit(code ?? exitCode);
  }

  try {
    final String flutterExecutable = '${inputs.flutterPath}/bin/flutter';

    // Command to disable analytics reporting, and also to prevent a warning from the next command due to Flutter welcome screen
    await _runCommand(
      flutterExecutable,
      const <String>['config', '--no-analytics'],
    );

    // Installing pana package
    stderr.writeln('Activating pana package...');
    final int panaActivationExitCode = (await _runCommand(
      flutterExecutable,
      const <String>['pub', 'global', 'activate', 'pana'],
    ))
        .exitCode;

    if (panaActivationExitCode != 0) {
      await _exitProgram(panaActivationExitCode);
    }

    unawaited(analysis.start());

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
        inputs.sourcePath,
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
      pathPrefix: inputs.packagePath,
      result: result,
      minAnnotationLevel: inputs.minAnnotationLevel,
    );

    exitCode = 0;
  } catch (e, s) {
    _writeErrors(e, s);
    tryCancelAnalysis();
    rethrow;
  }
}

/// Runs a command and prints its outputs to stderr and stdout while running.
/// Returns a [_ProcessResult] with the sdtout output in a String.
Future<_ProcessResult> _runCommand(
  String executable,
  List<String> arguments,
) async {
  Future<List<String>> output;
  Future<dynamic> addStreamOut;
  Future<dynamic> addStreamErr;
  final Future<List<dynamic>> Function() freeStreams =
      () async => Future.wait<dynamic>([addStreamErr, addStreamOut]);
  try {
    final int code =
        await Process.start(executable, arguments, runInShell: true)
            .then((final Process process) {
      addStreamErr = stderr.addStream(process.stderr);
      final Stream<List<int>> outBrStream = process.stdout.asBroadcastStream();
      addStreamOut = stdout.addStream(outBrStream);
      output = outBrStream.transform(utf8.decoder).toList();
      return process.exitCode;
    });
    await freeStreams();
    return _ProcessResult(exitCode: code, output: (await output)?.join());
  } catch (e) {
    await freeStreams();
    rethrow;
  }
}

void _writeErrors(dynamic error, StackTrace stackTrace) {
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
