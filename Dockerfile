FROM google/dart-runtime

#COPY LICENSE README.md /

#COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
