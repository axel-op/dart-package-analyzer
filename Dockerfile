FROM google/dart:latest

# Install Flutter
RUN apt-get update \
    && apt-get -y install unzip \
    && git clone -b stable https://github.com/flutter/flutter.git /flutter \
    && /flutter/bin/flutter --version \
    && /flutter/bin/flutter --version

COPY LICENSE README.md /

COPY main.dart.aot /main.dart.aot

#ENV PATH="$PATH:/usr/lib/dart/bin"

#RUN pub global activate pana

ENTRYPOINT ["dartaotruntime", "/main.dart.aot", "-f", "/flutter", "-p", "/github/workspace"]
