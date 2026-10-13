FROM dhi.io/debian-base:trixie-debian13-dev

COPY common/assets/99-force-confdef /etc/apt/apt.conf.d/99-force-confdef
RUN apt-get update && apt-get upgrade --yes && apt-get clean
RUN apt-get install --no-install-recommends --assume-yes awscli-2 jq bsdutils uuid-runtime && apt-get clean

RUN mkdir -p /opt/task /opt/lib
COPY scripts/bin/repository-cleanup /usr/local/bin/cleanup
COPY scripts/lib /usr/local/lib

ENTRYPOINT ["/usr/local/bin/cleanup"]
