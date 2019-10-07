import 'dart:convert';
import 'dart:io';

import 'package:app/event.dart';
import 'package:app/github.dart';
import 'package:app/result.dart';
import 'package:app/utils.dart';
import 'package:args/args.dart';
import 'package:meta/meta.dart';

class _Argument {
  final String fullName;
  final String abbreviation;
  final bool nullable;
  const _Argument(this.fullName, this.abbreviation, {@required this.nullable});
}

const List<_Argument> arguments = <_Argument>[
  _Argument('repo_path', 'r', nullable: false),
  _Argument('github_token', 't', nullable: false),
  _Argument('event_payload', 'e', nullable: false),
  _Argument('fluttersdk_path', 'f', nullable: false),
  _Argument('commit_sha', 'c', nullable: false),
  _Argument('max_score', 'm', nullable: true),
  _Argument('package_path', 'p', nullable: true),
];

dynamic main(List<String> args) async {
  exitCode = 1;

  // Parse command arguments
  final ArgParser argparser = ArgParser();
  arguments.forEach((_Argument arg) =>
      argparser.addOption(arg.fullName, abbr: arg.abbreviation));
  final ArgResults argresults = argparser.parse(args);
  arguments.forEach((_Argument arg) {
    if (argresults[arg.fullName] == null && !arg.nullable) {
      stderr.writeln(
          'No value were given for the argument \'${arg.fullName}\'. Exiting.');
      exit(1);
    }
  });
  final String repoPath = argresults['repo_path'];
  final String flutterPath = argresults['fluttersdk_path'];
  final String eventPayload = argresults['event_payload'];
  final String githubToken = argresults['github_token'];
  final String commitSha = argresults['commit_sha'];
  final dynamic maxScoreUnknownType = argresults['max_score'];
  final num maxScore =
      maxScoreUnknownType != null && maxScoreUnknownType is String
          ? num.parse(maxScoreUnknownType)
          : maxScoreUnknownType;
  String packagePathUnformatted = argresults['package_path'] ?? '';
  if (!packagePathUnformatted.startsWith('/') && !repoPath.endsWith('/')) {
    packagePathUnformatted = '/' + packagePathUnformatted;
  }
  final String sourcePath = repoPath + packagePathUnformatted;

  // Install pana package
  await _runCommand('pub', <String>['global', 'activate', 'pana'],
      exitOnError: true);

  // Command to disable analytics reporting, and also to prevent a warning from the next command due to Flutter welcome screen
  await _runCommand(
      '$flutterPath/bin/flutter', <String>['config', '--no-analytics']);

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
        flutterPath,
        '--source',
        'path',
        sourcePath,
      ],
      exitOnError: true);

  if (outputPana == null) throw ArgumentError.notNull('outputPana');
  final Map<String, dynamic> resultPana = jsonDecode(outputPana);
  final Event event = getEvent(jsonDecode(eventPayload));
  final Result result = processOutput(resultPana);
  final String comment = buildComment(result, event, commitSha);

  // Post a comment on GitHub
  if (maxScore != null &&
      result.healthScore > maxScore &&
      result.maintenanceScore > maxScore) {
    stdout.writeln(
        'Health score and maintenance score are both higher than the maximum score, so no general commit comment will be made.' +
            (result.lineSuggestions.isNotEmpty
                ? ' However, specific comments are still posted under each line where static analysis has found an issue.'
                : ''));
    exitCode = 0;
  } else {
    exitCode = 0;
    await postCommitComment(
      comment,
      event: event,
      githubToken: githubToken,
      commitSha: commitSha,
      onError: (dynamic e, dynamic s) async {
        _writeErrors(e, s);
        exitCode = 1;
      },
    );
  }

  // Post file-specific comments on GitHub
  /* Deactivated for now, as the API deprecated the line parameter, and should now be given the diff's position
  for (final LineSuggestion suggestion in results.lineSuggestions) {
    await postCommitComment(
      suggestion.description,
      event: event,
      githubToken: githubToken,
      commitSha: commitSha,
      lineNumber: suggestion.lineNumber,
      fileRelativePath: suggestion.relativePath,
      onError: (dynamic e, dynamic s) async {
        _writeErrors(e, s);
        exitCode = 1;
      },
    );
  }*/
}

/// Runs a command and prints its outputs to stderr and stdout while running.
/// Returns the sdtout output in a String.
Future<String> _runCommand(String executable, List<String> arguments,
    {bool exitOnError = false}) async {
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
