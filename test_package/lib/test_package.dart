library test_package;

class Test {
  // dummy comment
  final int valueTest2;
  const Test({
    @deprecated this.valueTest2,
  });
}

class Test2 {
  final int value;
  const Test2({
    @deprecated this.value,
  });
}

/// A Calculator.
class Calculator {
  /// Returns [value] plus 1.
  int addOne(int value) => value + 1;
}

class Test3 {
  @deprecated
  final valueDeprecated;
  const Test3(@deprecated this.valueDeprecated);
}

void dummyFunction() {
  const t3 = Test3(1);
  final sum = t3.valueDeprecated + 1;
}

class Calculator2 {
  /// Returns [value] plus 1.
  int addOne(int value) => value + 1;
}
