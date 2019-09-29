FROM google/dart:latest

COPY LICENSE README.md /

COPY main.dart.aot /main.dart.aot

ENV PATH="$PATH:/usr/lib/dart/bin"

#RUN pub global activate pana

ENTRYPOINT ["dartaotruntime", "/main.dart.aot", "-p", "/github/workspace"]
