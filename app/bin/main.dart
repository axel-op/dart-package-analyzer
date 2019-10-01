import 'dart:convert';
import 'dart:io';

import 'package:app/app.dart' as app;
import 'package:app/app.dart';
import 'package:app/event.dart';
import 'package:app/result.dart';
import 'package:args/args.dart';

main(List<String> arguments) async {
  exitCode = 1;

  // Parse command arguments
  final ArgParser argparser = ArgParser()
    ..addOption('package_path', abbr: 'p')
    ..addOption('github_token', abbr: 't')
    ..addOption('event_payload', abbr: 'e')
    ..addOption('fluttersdk_path', abbr: 'f')
    ..addOption('commit_sha', abbr: 'c')
    ..addOption('max_score', abbr: 'm');
  final ArgResults argresults = argparser.parse(arguments);
  final String package_path = argresults['package_path'];
  final String flutter_path = argresults['fluttersdk_path'];
  final String eventPayload = argresults['event_payload'];
  final String githubToken = argresults['github_token'];
  final String commitSha = argresults['commit_sha'];
  final dynamic maxScoreUnknownType = argresults['max_score'];
  final num maxScore = maxScoreUnknownType is String
      ? num.parse(maxScoreUnknownType)
      : maxScoreUnknownType;

  // Install pana package
  await _runCommand('pub', ['global', 'activate', 'pana'], exitOnError: true);

  // Dummy command to prevent a warning from the next command
  await _runCommand('$flutter_path/bin/flutter', ['version']);

  // Execute the analysis
  final String outputPana = await _runCommand(
      'pub',
      [
        'global',
        'run',
        'pana',
        '--scores',
        '--no-warning',
        '--flutter-sdk',
        flutter_path,
        '--source',
        'path',
        package_path,
      ],
      exitOnError: true);

  final Map<String, dynamic> resultPana = jsonDecode(outputPana);
  final Event event = getEvent(jsonDecode(eventPayload));
  final Result results = app.processOutput(resultPana);
  final String comment = app.buildComment(results, event, commitSha);

  // Post a comment on GitHub
  if (results.healthScore > maxScore && results.maintenanceScore > maxScore) {
    stdout.write(
        'Health score and maintenance score are both higher than the maximum score, so no comment will be posted.');
    exitCode = 0;
  } else {
    exitCode = 0;
    await postCommitComment(comment,
        event: event,
        githubToken: githubToken,
        commitSha: commitSha, onError: (e, s) async {
      _writeErrors(e, s);
      exitCode = 1;
    });
  }

  // Post file-specific comments on GitHub
  for (final LineSuggestion suggestion in results.lineSuggestions) {
    await app.postCommitComment(suggestion.description,
        event: event,
        githubToken: githubToken,
        commitSha: commitSha,
        lineNumber: suggestion.lineNumber,
        fileRelativePath: suggestion.relativePath, onError: (e, s) async {
      _writeErrors(e, s);
      exitCode = 1;
    });
  }
}

/// Runs a command and prints its outputs to stderr and stdout while running.
/// Returns the sdtout output in a String.
Future<String> _runCommand(String executable, List<String> arguments,
    {bool exitOnError = false}) async {
  Future<List<String>> output;
  Future<dynamic> addStreamOut;
  Future<dynamic> addStreamErr;
  try {
    final int code =
        await Process.start(executable, arguments, runInShell: true)
            .then((process) {
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
    await Future.wait([addStreamErr, addStreamOut]);
    _writeErrors(e, s);
    await _exitProgram(1);
  }
  await Future.wait([addStreamErr, addStreamOut]);
  return (await output).join();
}

void _writeErrors(dynamic error, dynamic stackTrace) {
  stderr.write(error.toString() + '\n' + stackTrace.toString());
}

Future<void> _exitProgram([int code]) async {
  await Future.wait([stderr.done, stdout.done]);
  exit(code != null ? code : exitCode);
}
