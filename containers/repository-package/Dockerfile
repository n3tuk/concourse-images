FROM dhi.io/debian-base:trixie-debian13-dev

COPY common/assets/99-force-confdef /etc/apt/apt.conf.d/99-force-confdef
RUN apt-get update && apt-get upgrade --yes && apt-get clean
RUN apt-get install --no-install-recommends --assume-yes awscli-2 jq bsdutils uuid-runtime && apt-get clean

RUN mkdir -p /opt/resource /opt/lib
COPY scripts/bin/repository-package-check /opt/resource/check
COPY scripts/bin/repository-package-out /opt/resource/out
COPY scripts/bin/repository-package-in /opt/resource/in
COPY scripts/lib /opt/lib

RUN useradd --system --create-home --home-dir /database --skel /dev/null --user-group database
USER database
WORKDIR /database

ENTRYPOINT ["/opt/resource/in"]
