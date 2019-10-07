library test_package;

class Test {
  final int valueTest3;
  const Test({
    @deprecated this.valueTest3,
  });
}

class Test2 {
  final int value4;
  const Test2({
    @deprecated this.value4,
  });
}

/// A Calculator.
class Calculator {
  /// Returns [value] plus 1.
  int addOne(int value) => value + 1;
}

class Test3 {
  @deprecated
  final value;
  const Test3(@deprecated this.value);
}

void dummyFunction() {
  const t3 = Test3(1);
  final sum = t3.value + 1;
}

class Calculator2 {
  /// Returns [value] plus 1.
  int addOne(int value) => value + 1;
}

void dummyFunction2() {
  const t3 = Test3(1);
  final sum = t3.value + 1;
}
