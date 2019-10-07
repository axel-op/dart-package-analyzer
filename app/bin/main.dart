import 'dart:convert';
import 'dart:io';

import 'package:app/args.dart';
import 'package:app/event.dart';
import 'package:app/github.dart';
import 'package:app/result.dart';
import 'package:app/utils.dart';

dynamic main(List<String> args) async {
  exitCode = 1;

  // Parse command arguments
  final Arguments arguments = parseArgs(args);

  // Install pana package
  await _runCommand(
    'pub',
    const <String>['global', 'activate', 'pana'],
    exitOnError: true,
  );

  // Command to disable analytics reporting, and also to prevent a warning from the next command due to Flutter welcome screen
  await _runCommand(
    '${arguments.flutterPath}/bin/flutter',
    const <String>['config', '--no-analytics'],
  );

  // Execute the analysis
  final String outputPana = await _runCommand(
    'pub',
    <String>[
      'global',
      'run',
      'pana',
      '--scores',
      '--no-warning',
      '--flutter-sdk',
      arguments.flutterPath,
      '--source',
      'path',
      arguments.sourcePath,
    ],
    exitOnError: true,
  );

  if (outputPana == null) throw ArgumentError.notNull('outputPana');
  final Map<String, dynamic> resultPana = jsonDecode(outputPana);
  final Event event = getEvent(jsonDecode(arguments.eventPayload));
  final Result result = processOutput(resultPana);
  final String comment = buildComment(result, event, arguments.commitSha);

  const String noComment =
      'Health score and maintenance score are both higher than the maximum score, so no general commit comment will be made.';

  // Post a comment on GitHub
  if (arguments.maxScoreToComment != null &&
      result.healthScore > arguments.maxScoreToComment &&
      result.maintenanceScore > arguments.maxScoreToComment) {
    stdout.writeln(noComment);
    exitCode = 0;
  } else {
    exitCode = 0;
    await postCommitComment(
      comment,
      event: event,
      githubToken: arguments.githubToken,
      commitSha: arguments.commitSha,
      onError: (dynamic e, dynamic s) async {
        _writeErrors(e, s);
        exitCode = 1;
      },
    );
  }

  // Post file-specific comments on GitHub
  for (final LineSuggestion suggestion in result.lineSuggestions) {
    await postCommitComment(
      suggestion.description,
      event: event,
      githubToken: arguments.githubToken,
      commitSha: arguments.commitSha,
      lineNumber: suggestion.lineNumber,
      fileRelativePath: '${arguments.packagePath}/${suggestion.relativePath}',
      onError: (dynamic e, dynamic s) async {
        _writeErrors(e, s);
        exitCode = 1;
      },
    );
  }
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
  final Future<List<dynamic>> Function() freeStreams = () async =>
      await Future.wait(<Future<dynamic>>[addStreamErr, addStreamOut]);
  try {
    final int code =
        await Process.start(executable, arguments, runInShell: true)
            .then((Process process) {
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
    await freeStreams();
    _writeErrors(e, s);
    await _exitProgram(1);
  }
  await freeStreams();
  return (await output)?.join();
}

void _writeErrors(dynamic error, dynamic stackTrace) {
  stderr.writeln(error.toString() + '\n' + stackTrace.toString());
}

Future<void> _exitProgram([int code]) async {
  await Future.wait(<Future<dynamic>>[stderr.done, stdout.done]);
  exit(code != null ? code : exitCode);
}
