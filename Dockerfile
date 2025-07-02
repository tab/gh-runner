FROM debian:12.6-slim

ENV DEBIAN_FRONTEND=noninteractive \
  VERSION=2.325.0

RUN apt-get update && \
  apt-get install -y --no-install-recommends \
    curl \
    git \
    sudo \
    unzip \
    jq \
    ca-certificates \
    libicu-dev \
    libkrb5-3 \
    zlib1g && \
  rm -rf /var/lib/apt/lists/* && \
  useradd -m runner && \
  echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER runner
WORKDIR /home/runner

COPY --chmod=755 entrypoint.sh /home/runner/entrypoint.sh

ENTRYPOINT ["/home/runner/entrypoint.sh"]
