import 'dart:convert';
import 'dart:io';

import 'package:app/github.dart';
import 'package:app/inputs.dart';
import 'package:app/pana_result.dart';
import 'package:github_actions_toolkit/github_actions_toolkit.dart' as gaction;

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

  Future<void> _exitProgram([dynamic cause]) async {
    await tryCancelAnalysis(cause);
    await Future.wait<dynamic>([stderr.done, stdout.done]);
    gaction.setErrorMessage('Exiting with code $exitCode');
    exit(exitCode);
  }

  try {
    // Command to disable analytics reporting, and also to prevent a warning from the next command due to Flutter welcome screen
    await gaction.group(
      'Disabling Flutter analytics',
      () => gaction.exec('flutter', const <String>['config', '--no-analytics']),
    );

    await analysis.start();

    // Executing the analysis
    gaction.startGroup('Running pana');
    final panaProcessResult = await gaction.exec(
      'pana',
      <String>[
        '--scores',
        '--no-warning',
        '--source',
        'path',
        inputs.paths.canonicalPathToPackage,
      ],
    );
    gaction.endGroup();

    if (panaProcessResult.exitCode != 0) {
      gaction.setErrorMessage(
          'Pana exited with code ${panaProcessResult.exitCode}');
      exitCode = panaProcessResult.exitCode;
      await _exitProgram();
    }
    if (panaProcessResult.stdout == null) {
      throw Exception('The pana command has returned no valid output.'
          ' This should never happen.'
          ' Please file an issue at https://github.com/axel-op/dart-package-analyzer/issues/new');
    }

    final panaResult = PanaResult.fromOutput(
      jsonDecode(panaProcessResult.stdout) as Map<String, dynamic>,
      paths: inputs.paths,
    );

    // Posting comments on GitHub
    await gaction.group(
      'Publishing report',
      () async => analysis.complete(
        panaResult: panaResult,
        minAnnotationLevel: inputs.minAnnotationLevel,
      ),
    );

    // Setting outputs
    await gaction.group(
      'Setting outputs',
      () async {
        for (final output in [
          ['health', panaResult.healthScore.toStringAsFixed(2)],
          ['maintenance', panaResult.maintenanceScore.toStringAsFixed(2)],
          ['errors', panaResult.analyzerResult.errorCount.toString()],
          ['warnings', panaResult.analyzerResult.warningCount.toString()],
          ['hints', panaResult.analyzerResult.hintCount.toString()]
        ]) {
          gaction.setOutput(output[0], output[1]);
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
  gaction.setErrorMessage(error.toString() +
      (stackTrace != null ? '\n' + stackTrace.toString() : ''));
}
