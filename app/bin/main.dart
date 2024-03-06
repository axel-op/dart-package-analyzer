import 'dart:convert';
import 'dart:io';

import 'package:app/github.dart';
import 'package:app/inputs.dart';
import 'package:app/report.dart';
import 'package:github_actions_toolkit/github_actions_toolkit.dart' as gaction;

const logger = gaction.log;

dynamic main(List<String> args) async {
  exitCode = 0;

  // Parsing user inputs and environment variables
  final Inputs inputs = Inputs();

  final Analysis analysis = await Analysis.queue(
    commitSha: inputs.commitSha,
    githubToken: inputs.githubToken,
    repositorySlug: inputs.repositorySlug,
  );

  Future<void> tryCancelAnalysis(dynamic cause) async {
    try {
      await analysis.cancel(cause: cause);
    } catch (e, s) {
      _writeError(e, s);
    }
  }

  Future<void> exitProgram([dynamic cause]) async {
    await tryCancelAnalysis(cause);
    await Future.wait<dynamic>([stderr.done, stdout.done]);
    logger.error('Exiting with code $exitCode');
    exit(exitCode);
  }

  try {
    final canonicalPathToRepoRoot = inputs.paths.canonicalPathToRepoRoot;
    final userProcessResult = await gaction.exec('whoami', [], silent: true);
    final user = (userProcessResult.stdout as String).trim();
    logger.info('whoami returned: $user');
    await gaction.exec('chown', [user, '-R', canonicalPathToRepoRoot]);

    // Command to disable analytics reporting, and also to prevent a warning from the next command due to Flutter welcome screen
    await logger.group(
      'Disabling Flutter analytics',
      () => gaction.exec('flutter', const ['config', '--no-analytics']),
    );

    await analysis.start();

    // Executing the analysis
    logger.startGroup('Running pana');
    final panaProcessResult = await gaction.exec(
      'pana',
      ['--json', '--no-warning', inputs.paths.canonicalPathToPackage],
    );
    logger.endGroup();

    if (panaProcessResult.exitCode != 0) {
      logger.error('Pana exited with code ${panaProcessResult.exitCode}');
      exitCode = panaProcessResult.exitCode;
      await exitProgram();
    }
    if (panaProcessResult.stderr
        .toLowerCase()
        .contains("can't load kernel binary")) {
      throw Exception("SDK incompatibility");
    }
    if (panaProcessResult.stdout == null) {
      throw Exception('The pana command has returned no valid output.'
          ' This should never happen.'
          ' Please file an issue at https://github.com/axel-op/dart-package-analyzer/issues/new');
    }

    final report = Report.fromOutput(
        jsonDecode(panaProcessResult.stdout) as Map<String, dynamic>);

    if (report.errorMessage != null) {
      throw Exception(report.errorMessage);
    }

    // Posting comments on GitHub
    await logger.group(
      'Publishing report',
      () async => analysis.complete(report: report),
    );

    // Setting outputs
    await logger.group(
      'Setting outputs',
      () async {
        final outputs = <String, String>{
          "json_output": jsonEncode(jsonDecode(panaProcessResult.stdout)),
          "total": report.grantedPoints.toString(),
          "total_max": report.maxPoints.toString()
        };
        final idsToKeys = <String, String>{
          "convention": "conventions",
          "documentation": "documentation",
          "platform": "platforms",
          "analysis": "analysis",
          "dependency": "dependencies",
          "null-safety": "null_safety",
        };
        for (final section in report.sections) {
          final key = idsToKeys[section.id] ?? section.id;
          outputs[key] = section.grantedPoints.toString();
          outputs["${key}_max"] = section.maxPoints.toString();
        }
        for (final output in outputs.entries) {
          logger.info('${output.key}: ${output.value}');
          gaction.setOutput(output.key, output.value);
        }
      },
    );
  } catch (e) {
    //_writeErrors(e, s); // useless if we rethrow it
    await tryCancelAnalysis(e);
    rethrow;
  }
}

void _writeError(dynamic error, StackTrace stackTrace) {
  logger.error('$error\n$stackTrace');
}
