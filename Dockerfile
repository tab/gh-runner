FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV VERSION=2.325.0

RUN apt-get update && apt-get install -y \
  curl \
  git \
  sudo \
  unzip \
  jq \
  ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -m runner && echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER runner
WORKDIR /home/runner

COPY entrypoint.sh entrypoint.sh
RUN chmod +x entrypoint.sh

ENTRYPOINT ["/home/runner/entrypoint.sh"]

