library test_package;

/// A Calculator.
class Calculator {
  /// Returns [value] plus 1.
  int addOne(int value) => value + 1;
}

class Test {
  final int value;
  const Test({
    @deprecated this.value,
  });
}
