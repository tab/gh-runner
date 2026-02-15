FROM alpine:3.23 AS runner-downloader

ARG RUNNER_VERSION=2.331.0
ARG TARGETARCH

RUN apk add --no-cache curl tar

WORKDIR /tmp

RUN case "${TARGETARCH}" in \
      amd64) ARCH="x64" ;; \
      arm64) ARCH="arm64" ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    curl -fsSL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz" \
      -o actions-runner.tar.gz && \
    mkdir -p /actions-runner && \
    tar xzf actions-runner.tar.gz -C /actions-runner && \
    rm actions-runner.tar.gz

FROM docker:28-cli AS docker-cli

FROM alpine:3.23 AS goose-downloader

ARG GOOSE_VERSION=v3.24.3
ARG TARGETARCH

RUN apk add --no-cache curl

WORKDIR /tmp

RUN case "${TARGETARCH}" in \
      amd64) GOOSE_ARCH="x86_64" ;; \
      arm64) GOOSE_ARCH="arm64" ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    curl -fsSL "https://github.com/pressly/goose/releases/download/${GOOSE_VERSION}/goose_linux_${GOOSE_ARCH}" \
      -o goose && \
    chmod +x goose

FROM debian:13.3-slim AS runtime

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      jq \
      make \
      sudo \
      libicu-dev \
      libkrb5-3 \
      zlib1g \
      unzip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* && \
    rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/* /usr/share/locale/* && \
    rm -rf /var/cache/apt/*

RUN groupadd -g 1001 runner && \
    useradd -u 1001 -g runner -m -s /bin/bash runner && \
    echo "runner ALL=(ALL) NOPASSWD: /usr/bin/apt-get update, /usr/bin/apt-get install, /usr/bin/dpkg, /usr/bin/chown, /usr/bin/mkdir, /usr/sbin/groupadd, /usr/sbin/groupmod, /usr/sbin/usermod" >> /etc/sudoers && \
    mkdir -p /home/runner/go/bin

COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
RUN mkdir -p /usr/local/lib/docker/cli-plugins
COPY --from=docker-cli /usr/local/libexec/docker/cli-plugins/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose

COPY --from=goose-downloader --chown=runner:runner --chmod=755 /tmp/goose /home/runner/go/bin/goose

COPY --from=runner-downloader --chown=runner:runner /actions-runner /home/runner/actions-runner

ENV PATH="/home/runner/go/bin:${PATH}" \
    RUNNER_ALLOW_RUNASROOT=0

USER runner
WORKDIR /home/runner

COPY --chown=runner:runner --chmod=755 entrypoint.sh ./entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
