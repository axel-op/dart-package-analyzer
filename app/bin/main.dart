import 'dart:convert';
import 'dart:io';

import 'package:app/app.dart' as app;
import 'package:app/event.dart';
import 'package:app/result.dart';
import 'package:args/args.dart';
import 'package:github/server.dart' hide Event, PullRequest;

main(List<String> arguments) async {
  exitCode = 1;

  // Parse command arguments
  final ArgParser argparser = ArgParser();
  argparser
    ..addOption('package_path', abbr: 'p')
    ..addOption('github_token', abbr: 't')
    ..addOption('event_payload', abbr: 'e')
    ..addOption('fluttersdk_path', abbr: 'f')
    ..addOption('commit_sha', abbr: 'c');
  final ArgResults argresults = argparser.parse(arguments);
  final String package_path = argresults['package_path'];
  final String flutter_path = argresults['fluttersdk_path'];
  final String eventPayload = argresults['event_payload'];
  final String githubToken = argresults['github_token'];
  final String commitSha = argresults['commit_sha'];

  // Install pana package
  await _runCommand('pub', ['global', 'activate', 'pana'], exitOnError: true);

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
  try {
    final GitHub github =
        createGitHubClient(auth: Authentication.withToken(githubToken));
    final Repository repo = await github.repositories
        .getRepository(RepositorySlug.full(event.repoSlug));
    if (event is PullRequest) {
      await github.issues.createComment(repo.slug(), event.number, comment);
    } else {
      final RepositoryCommit commit =
          await github.repositories.getCommit(repo.slug(), commitSha);
      await github.repositories
          .createCommitComment(repo.slug(), commit, body: comment);
    }
    exitCode = 0;
  } catch (e, s) {
    _writeErrors(e, s);
    exitCode = 1;
  }
}

/// Run a command and print its outputs to stderr and stdout while running.
/// Returns the sdtout output in a String.
Future<String> _runCommand(String executable, List<String> arguments,
    {bool exitOnError = false}) async {
  Future<List<String>> output;
  try {
    final Process process =
        await Process.start(executable, arguments, runInShell: true)
            .then((process) {
      stderr.addStream(process.stderr);
      stdout.addStream(process.stdout);
      output = process.stdout.transform(utf8.decoder).toList();
      return process;
    });
    final int code = await process.exitCode;
    if (exitOnError && code != 0) {
      await _exitProgram(code);
    }
  } catch (e, s) {
    _writeErrors(e, s);
    await _exitProgram(1);
  }
  return (await output).join();
}

void _writeErrors(dynamic error, dynamic stackTrace) {
  stderr.write(error.toString() + '\n' + stackTrace.toString());
}

Future<void> _exitProgram([int code]) async {
  await stderr.done;
  await stdout.done;
  exit(code != null ? code : exitCode);
}
