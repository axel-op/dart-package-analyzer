library test;

class Test {
  final int valueTest;
  const Test({
     @deprecated this.valueTest,
  });
}

class Test2 {
  final int  valueA;
  const Test2({
    @deprecated this.valueA,
  });
}

/// A Calculator.
class Calculator {
  /// Returns [value] plus 1.
  int addOne(int value) => value + 1;
}

class Test3 {
  @deprecated
  final valueTest;
  const Test3(@deprecated this.valueTest);
}

void dummyFunction() {
  const t3 = Test3(1);
  final sum = t3.valueTest + 1;
}

class Calculator2 {
  /// Returns [value] plus 1.
  int addOne(int value) => value + 1;
}

void dummyFunction2() {
  const t3 = Test3(1);
  final sumTest = t3.valueTest + 1;
}
