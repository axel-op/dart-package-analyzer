FROM axelop/dart-with-flutter

ENTRYPOINT ["dartaotruntime", "/main.dart.aot"]
