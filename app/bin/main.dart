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
    ..addOption('event_payload', abbr: 'e');
  final ArgResults argresults = argparser.parse(arguments);
  final String path = argresults['package_path'];
  final String eventPayload = argresults['event_payload'];
  final String githubToken = argresults['github_token'];

  final ProcessResult result = Process.runSync('pub',
      ['global', 'run', 'pana', '--source', path, '--scores', '--no-warning'],
      runInShell: true);
  if (result.stderr != null) stderr.write(result.stderr);
  if (result.stdout != null) stdout.write(result.stdout);
  if (result.exitCode != 0) exit(1);
  final Map<String, dynamic> output = jsonDecode(result.stdout);

  final Event event = getEvent(jsonDecode(eventPayload));
  final Result results = app.processOutput(output);
  final String comment = app.buildComment(results, event);

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
  })
  .catchError((e, s) {
    stderr.write(e.toString());
    stderr.write(s.toString());
    exit(1);
  });
}
