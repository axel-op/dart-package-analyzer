# Dart/Flutter package analyzer

This action uses the [pana (Package ANAlysis) package](https://pub.dev/packages/pana) to compute the score that your Dart or Flutter package will have on the [Pub site](https://pub.dev/help), and annotates your code, with suggestions for improvements.

This package, amongst other things:

* validates the code by performing static analysis with [dartanalyzer](https://dart.dev/tools/dartanalyzer),
* checks code formatting with [`dartfmt`](https://dart.dev/tools/dartfmt) or [`flutter format`](https://flutter.dev/docs/development/tools/formatting#automatically-formatting-code-with-the-flutter-command) (detected automatically),
* checks for outdated dependencies,
* validates the `pubspec.yaml` file (dependencies, description's length...),
* checks for required files (`CHANGELOG`, `README`, `example` folder...)
* ...

## Usage

You must include the `actions/checkout` step in your workflow. You **don't** need to run `pub get` or build a Dart container before.

Here's an example:

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
          # Optional:
          relativePath: packages/mypackage/
          minAnnotationLevel: info
```

* `githubToken` input is required to post a report on GitHub. **Note:** the secret [`GITHUB_TOKEN`](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/authenticating-with-the-github_token) is already provided by GitHub and you don't have to set it up yourself.
* If your package isn't at the root of the repository, use `relativePath` to indicate its location.
* If you only want to see annotations for important errors, try to change the `minAnnotationLevel` parameter to another value. Accepted values are `info`, `warning` and `error`. Defaults to `info` that posts all the annotations.

### Using the full Dart SDK

By default, this action uses the Dart SDK embedded in Flutter. It may not be the latest version of the Dart SDK. To use the latest version of the full Dart SDK, append `/with_full_sdk` to the path of this action. This will slightly increase the time to pull the container that this action uses.

In the example above, you would edit line 10 like this:

```yml
      - uses: axel-op/dart_package_analyzer/with_full_sdk@stable
```

## Examples

### Report

![](example_report.png)

### Diff annotations

![](example_annotation.png)
