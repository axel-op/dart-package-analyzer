FROM google/dart

COPY LICENSE README.md /

COPY entrypoint.sh /entrypoint.sh

ENV PATH="$PATH:/usr/lib/dart/bin"

#RUN pub global activate pana

ENTRYPOINT ["/entrypoint.sh"]
