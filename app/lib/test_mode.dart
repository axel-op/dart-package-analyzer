import 'dart:io';

final bool testing = Platform.environment['INPUT_TESTING'] == 'true';

void assertion(bool condition, {String message}) {
  if (testing && !condition) {
    throw AssertionError(message);
  }
}

void log(String something) {
  if (testing) stderr.writeln(something);
}
