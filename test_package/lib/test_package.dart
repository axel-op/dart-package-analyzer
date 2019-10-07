library test_package;

/// A Calculator.
class Calculator {
  /// Returns [value] plus 1.
  int addOne(int value) => value + 1;
}

class Test {
  final int valueTest;
  const Test({
    @deprecated this.valueTest,
  });
}

class Test2 {
  final int value;
  const Test2({
    @deprecated this.value,
  });
}

class Test3 {
  @deprecated
  final v;
  const Test3(@deprecated this.v);
}

void dummyFunction() {
  const t3 = Test3(1);
  final sum = t3.v + 1;
}
