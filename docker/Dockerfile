FROM debian:stable-slim

ARG PACKAGE=mattermax-*-linux-amd64.tar.gz
ARG PUID=2000
ARG PGID=2000

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    ca-certificates tzdata media-types poppler-utils wv unrtf tidy \
  && rm -rf /var/lib/apt/lists/*

ADD ${PACKAGE} /
RUN groupadd --gid "${PGID}" mattermax \
  && useradd --uid "${PUID}" --gid "${PGID}" --home-dir /mattermax --no-create-home --shell /usr/sbin/nologin mattermax \
  && mkdir -p /mattermax/data /mattermax/logs /mattermax/plugins /mattermax/client/plugins \
  && chown -R mattermax:mattermax /mattermax

ENV PATH="/mattermax/bin:${PATH}"
ENV MM_SERVICESETTINGS_ENABLELOCALMODE="true"
ENV MM_INSTALL_TYPE="docker"

USER mattermax
WORKDIR /mattermax

HEALTHCHECK --interval=30s --timeout=10s CMD ["mmctl", "system", "status", "--local"]
CMD ["mattermax"]
EXPOSE 8065 8067 8074
VOLUME ["/mattermax/data", "/mattermax/logs", "/mattermax/config", "/mattermax/plugins", "/mattermax/client/plugins"]
