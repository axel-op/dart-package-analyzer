library test_package;

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

/// A Calculator.
class Calculator {
  /// Returns [value] plus 1.
  int addOne(int value) => value + 1;
}

class Test3 {
  @deprecated
  final xyz;
  const Test3(@deprecated this.xyz);
}

void dummyFunction() {
  const t3 = Test3(1);
  final sum = t3.xyz + 1;
}

class Calculator2 {
  /// Returns [value] plus 1.
  int addOne(int value) => value + 1;
}
