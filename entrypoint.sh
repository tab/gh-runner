#!/bin/bash
set -euo pipefail

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a /home/runner/runner.log
}

error_exit() {
    log "ERROR: $1"
    exit 1
}

RUNNER_NAME="${RUNNER_NAME:-gh-runner-$(hostname)}"
GITHUB_REPO="${GITHUB_REPO:?ERROR: GITHUB_REPO environment variable is required}"
GITHUB_PAT="${GITHUB_PAT:?ERROR: GITHUB_PAT environment variable is required}"
RUNNER_LABELS="${RUNNER_LABELS:-docker,linux,$(uname -m)}"

log "Starting GitHub Actions Runner"
log "Repository: ${GITHUB_REPO}"
log "Runner Name: ${RUNNER_NAME}"
log "Labels: ${RUNNER_LABELS}"

if [ ! -w "/home/runner/_work" ]; then
    log "WARNING: No write access to _work directory"
    sudo chown -R runner:runner /home/runner/_work || log "Failed to fix _work permissions"
fi

cleanup() {
    log "Received termination signal, cleaning up..."
    if [ -f actions-runner/.runner ]; then
        log "Removing runner registration"
        cd actions-runner
        ./config.sh remove --token "${REMOVAL_TOKEN}" 2>/dev/null || log "Failed to remove runner registration"
    fi
    log "Cleanup completed"
    exit 0
}

trap cleanup SIGTERM SIGINT SIGQUIT SIGHUP

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

while true; do
    log "Runner starting..."
    if ./run.sh; then
        log "Runner exited normally"
        break
    else
        EXIT_CODE=$?
        log "Runner exited with code ${EXIT_CODE}"
        if [ ${EXIT_CODE} -eq 2 ]; then
            log "Runner requested restart, restarting in 5 seconds..."
            sleep 5
        else
            log "Runner failed, exiting..."
            exit ${EXIT_CODE}
        fi
    fi
done

log "Runner service completed"
