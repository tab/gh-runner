#!/bin/bash
set -euo pipefail

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

error_exit() {
    log "ERROR: $1"
    exit 1
}

RUNNER_NAME="${RUNNER_NAME:-gh-runner-$(hostname)}"
GITHUB_REPO="${GITHUB_REPO:?ERROR: GITHUB_REPO environment variable is required}"
GITHUB_PAT="${GITHUB_PAT:?ERROR: GITHUB_PAT environment variable is required}"
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,docker,linux,$(uname -m)}"

log "Starting GitHub Actions Runner"
log "Repository: ${GITHUB_REPO}"
log "Runner Name: ${RUNNER_NAME}"
log "Labels: ${RUNNER_LABELS}"

if [ ! -d "/home/runner/_work" ]; then
    log "Creating _work directory"
    mkdir -p /home/runner/_work
fi

if [ ! -w "/home/runner/_work" ]; then
    error_exit "No write access to _work directory. Please fix permissions on host: sudo chown -R 1001:1001 /volume1/docker/apps/gh-runner/biinge-api/work"
fi

cleanup() {
    log "Received termination signal, cleaning up..."
    if [ -f actions-runner/.runner ]; then
        log "Removing runner registration"
        cd actions-runner
        ./config.sh remove --token "${REMOVAL_TOKEN}" 2>/dev/null || log "Failed to remove runner registration"
    fi
    exit 0
}

trap cleanup SIGTERM SIGINT

# Docker socket access
if [ -S /var/run/docker.sock ]; then
    DOCKER_SOCK_GID=$(stat -c '%g' /var/run/docker.sock)
    if getent group docker > /dev/null 2>&1; then
        sudo groupmod -g "$DOCKER_SOCK_GID" docker
    else
        sudo groupadd -g "$DOCKER_SOCK_GID" docker
    fi
    sudo usermod -aG docker runner
    log "Docker socket detected (GID: $DOCKER_SOCK_GID), runner added to docker group"
fi

cd actions-runner

log "Registering runner to ${GITHUB_REPO}"

if ! TOKEN=$(curl -sf -X POST \
    -H "Authorization: token ${GITHUB_PAT}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/${GITHUB_REPO}/actions/runners/registration-token" | \
    jq -r '.token // empty'); then
    error_exit "Failed to get registration token from GitHub API"
fi

if [ -z "${TOKEN}" ] || [ "${TOKEN}" = "null" ]; then
    error_exit "Invalid or empty registration token received"
fi

REMOVAL_TOKEN=$(curl -sf -X POST \
    -H "Authorization: token ${GITHUB_PAT}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/${GITHUB_REPO}/actions/runners/remove-token" | \
    jq -r '.token // empty' 2>/dev/null || echo "")

log "Configuring runner"
if ! ./config.sh --unattended \
    --url "https://github.com/${GITHUB_REPO}" \
    --token "${TOKEN}" \
    --name "${RUNNER_NAME}" \
    --work "_work" \
    --labels "${RUNNER_LABELS}" \
    --replace; then
    error_exit "Failed to configure runner"
fi

log "Starting runner"
if [ -S /var/run/docker.sock ]; then
    exec sg docker -c "./run.sh"
else
    exec ./run.sh
fi
