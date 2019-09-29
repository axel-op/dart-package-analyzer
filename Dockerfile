FROM google/dart

COPY LICENSE README.md /

COPY entrypoint.sh /entrypoint.sh

RUN pub global activate pana

ENTRYPOINT ["/entrypoint.sh"]
