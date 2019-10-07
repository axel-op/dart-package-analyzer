# Dart/Flutter package analyzer

This action uses the [pana (Package ANAlysis) package](https://pub.dev/packages/pana) to compute the score that your Dart or Flutter package will have on the [Pub site](https://pub.dev/help), and posts it as a commit comment, with suggestions for improvements. 

This package, amongst other things:
* checks code formatting with [`dartfmt`](https://dart.dev/tools/dartfmt) or [`flutter format`](https://flutter.dev/docs/development/tools/formatting#automatically-formatting-code-with-the-flutter-command) (detected automatically),
* validates the code by performing static analysis with [dartanalyzer](https://dart.dev/tools/dartanalyzer),
* checks for outdated dependencies,
* validates the `pubscpec.yaml` file (dependencies, description's length...),
* checks for required files (`CHANGELOG`, `README`, `example` folder...)
* ...

## Example

![](example.png)

## Usage

You must include the `actions/checkout` step in your workflow. Here's an example:
```yml
name: Workflow example
on: [push, pull_request]

jobs:
  package-analysis:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v1 # required
      - uses: axel-op/dart_package_analyzer@stable
        with:
          # Required:
          githubToken: ${{ secrets.GITHUB_TOKEN }}
          eventPayload: ${{ toJson(github.event) }}
          commitSha: ${{ github.sha }}
          # Optional:
          maxScoreToComment: 99.99
          relativePath: 'packages/mypackage/'
```

* `githubToken`, `eventPayload`, and `commitSha` inputs are required to post a comment on GitHub.
* Use `maxScoreToComment` if you only want to have a comment if your score is lower than this. If you don't specify it, a comment will be posted for every commit that triggers the workflow. In this example, a comment won't be posted if the score is above 99.99, that is, if it equals 100. 
* If your package isn't at the root of the repository, use `relativePath` to indicate its location. 

