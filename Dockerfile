FROM axelop/dart-with-flutter

COPY app/ /app/

# Compile the Dart application that manages this action
RUN cd /app \
    && pub get \
    && dart2aot /app/bin/main.dart /main.dart.aot

ENTRYPOINT ["dartaotruntime", "/main.dart.aot"]
