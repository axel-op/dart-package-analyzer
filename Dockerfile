FROM axelop/dart_package_analyzer

ENTRYPOINT ["dartaotruntime", "/main.dart.aot"]
