import 'dart:convert';
import 'dart:io';

import 'package:app/app.dart' as app;
import 'package:app/event.dart';
import 'package:app/result.dart';
import 'package:args/args.dart';
import 'package:github/server.dart' as g;

main(List<String> arguments) {
  exitCode = 0;
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

  final ProcessResult resultPanaActivation =
      Process.runSync('pub', ['global', 'activate', 'pana'], runInShell: true);
  _writeOutputs(resultPanaActivation, exitOnError: true);
  final ProcessResult resultPana = Process.runSync(
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
      runInShell: true);
  _writeOutputs(resultPana, exitOnError: true);
  final Map<String, dynamic> output = jsonDecode(resultPana.stdout);

  final Event event = getEvent(jsonDecode(eventPayload));
  // To debug only
  stderr.write("DEBUGGING: repoId = ${event.repoId}");
  final Result results = app.processOutput(output);
  final String comment = app.buildComment(results, event, commitSha);

  final g.GitHub github =
      g.createGitHubClient(auth: g.Authentication.withToken(githubToken));
  github.repositories
      .getRepository(g.RepositorySlug.full(event.repoSlug))
      .then((repo) {
    if (event is PullRequest) {
      github.issues.createComment(repo.slug(), event.number, comment);
    } else {
      stderr.write("Commit comments aren't implemented yet.");
      exit(1);
      //github.git.getCommit(repo.slug(), event.commitId)
      //  .then((commit) => github.)
    }
  }).catchError((e, s) {
    stderr.write(e.toString());
    stderr.write(s.toString());
    exit(1);
  });
}

void _writeOutputs(ProcessResult processResult, {bool exitOnError = false}) {
  if (processResult.stderr != null) stderr.write(processResult.stderr);
  if (processResult.stdout != null) stdout.write(processResult.stdout);
  if (exitOnError && processResult.exitCode != 0) {
    stderr.done
        .then((_) => stdout.done)
        .then((_) => exit(processResult.exitCode));
  }
}
