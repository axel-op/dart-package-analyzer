import 'dart:convert';
import 'dart:io';

import 'package:app/github.dart';
import 'package:app/inputs.dart';
import 'package:app/result.dart';
import 'package:github/server.dart';

Inputs _inputs;
CheckRun _checkRun;

dynamic main(List<String> args) async {
  exitCode = 1;

  // Parsing command arguments
  _inputs = await getInputs(
    onError: (e, s) async {
      _writeErrors(e, s);
      await _exitProgram(1);
    },
  );

  // Displaying commit SHA
  stderr.writeln('This action will be run for commit ${_inputs.commitSha}');

  _checkRun = await queueAnalysis(
    commitSha: _inputs.commitSha,
    githubToken: _inputs.githubToken,
    repositorySlug: _inputs.repositorySlug,
    onError: (e, s) async {
      _writeErrors(e, s);
      await _exitProgram(1);
    },
  );

  final String flutterExecutable = '${_inputs.flutterPath}/bin/flutter';

  // Command to disable analytics reporting, and also to prevent a warning from the next command due to Flutter welcome screen
  await _runCommand(
    flutterExecutable,
    const <String>['config', '--no-analytics'],
  );

  // Installing pana package
  stderr.writeln('Activating pana package...');
  await _runCommand(
    flutterExecutable,
    const <String>['pub', 'global', 'activate', 'pana'],
    exitOnError: true,
  );

  await startAnalysis(
    checkRun: _checkRun,
    githubToken: _inputs.githubToken,
    repositorySlug: _inputs.repositorySlug,
    onError: (e, s) async {
      _writeErrors(e, s);
      await _exitProgram(1);
    },
  );

  // Executing the analysis
  stderr.writeln('Running analysis...');
  final String outputPana = await _runCommand(
    flutterExecutable,
    <String>[
      'pub',
      'global',
      'run',
      'pana',
      '--scores',
      '--no-warning',
      '--flutter-sdk',
      _inputs.flutterPath,
      '--source',
      'path',
      _inputs.sourcePath,
    ],
    exitOnError: true,
  );

  if (outputPana == null) {
    stderr.writeln('The pana command has returned no valid output. Exiting.');
    await _exitProgram(1);
  }
  final Map<String, dynamic> resultPana = jsonDecode(outputPana);
  final Result result = Result.fromOutput(resultPana);

  // Posting comments on GitHub
  exitCode = 0;
  await postResultsAndEndAnalysis(
    checkRun: _checkRun,
    pathPrefix: _inputs.packagePath,
    result: result,
    repositorySlug: _inputs.repositorySlug,
    githubToken: _inputs.githubToken,
    minAnnotationLevel: _inputs.minAnnotationLevel,
    onError: (e, s) async {
      _writeErrors(e, s);
      exitCode = 1;
    },
  );
}

/// Runs a command and prints its outputs to stderr and stdout while running.
/// Returns the sdtout output in a String.
Future<String> _runCommand(
  String executable,
  List<String> arguments, {
  bool exitOnError = false,
}) async {
  Future<List<String>> output;
  Future<dynamic> addStreamOut;
  Future<dynamic> addStreamErr;
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
    if (exitOnError && code != 0) {
      await _exitProgram(code);
    }
  } catch (e, s) {
    await Future.wait(<Future<dynamic>>[addStreamErr, addStreamOut]);
    _writeErrors(e, s);
    await _exitProgram(1);
  }
  await Future.wait(<Future<dynamic>>[addStreamErr, addStreamOut]);
  return (await output).join();
}

Future<void> _exitProgram([int code]) async {
  if (_checkRun != null) {
    await cancelAnalysis(
      checkRun: _checkRun,
      githubToken: _inputs.githubToken,
      repositorySlug: _inputs.repositorySlug,
      onError: (e, s) async => _writeErrors(e, s),
    );
  }
  await Future.wait(<Future<dynamic>>[stderr.done, stdout.done]);
  exit(code ?? exitCode);
}

void _writeErrors(dynamic error, StackTrace stackTrace) {
  stderr.writeln(error.toString() +
      (stackTrace != null ? '\n' + stackTrace.toString() : ''));
}
