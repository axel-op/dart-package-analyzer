FROM google/dart

COPY LICENSE README.md /

COPY entrypoint.dart /entrypoint.dart

ENV PATH="$PATH:/usr/lib/dart/bin"

#RUN pub global activate pana

ENTRYPOINT ["dart", "/entrypoint.dart", "first_arg"]
