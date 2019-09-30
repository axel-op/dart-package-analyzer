import 'package:meta/meta.dart';

Event getEvent(Map<String, dynamic> payload) {
  final bool isPullRequest = payload.containsKey('pull_request');
  final String repoId = payload['repository']['id'].toString();
  final String repoSlug = payload['repository']['full_name'];
  final String commitId = payload['after'];
  final int number = isPullRequest ? payload['pull_request']['number'] : null;
  return isPullRequest
      ? PullRequest._(
          number: number,
          commitId: commitId,
          repoId: repoId,
          repoSlug: repoSlug,
        )
      : Push._(
          commitId: commitId,
          repoId: repoId,
          repoSlug: repoSlug,
        );
}

class Event {
  final String commitId;
  final String repoId;
  final String repoSlug;

  Event._(
      {@required this.commitId,
      @required this.repoId,
      @required this.repoSlug});
}

class Push extends Event {
  Push._({
    @required String commitId,
    @required String repoId,
    @required String repoSlug,
  }) : super._(commitId: commitId, repoId: repoId, repoSlug: repoSlug);
}

class PullRequest extends Event {
  final int number;

  PullRequest._({
    @required this.number,
    @required String commitId,
    @required String repoId,
    @required String repoSlug,
  }) : super._(
          commitId: commitId,
          repoId: repoId,
          repoSlug: repoSlug,
        );
}
