FROM google/dart

# Install Flutter
RUN apt-get update \
    && apt-get -y install unzip \
    && git clone -b stable --depth 1 https://github.com/flutter/flutter.git /flutter \
    && /flutter/bin/flutter --version

COPY LICENSE README.md /

COPY main.dart.aot /main.dart.aot

#ENV PATH="$PATH:/usr/lib/dart/bin"

#RUN pub global activate pana

ENTRYPOINT ["dartaotruntime", "/main.dart.aot", "-f", "/flutter", "-p", "/github/workspace"]
