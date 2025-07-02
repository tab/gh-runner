#!/bin/bash
set -euo pipefail

RUNNER_NAME=${RUNNER_NAME:-gh-runner}
GITHUB_REPO_URL=${GITHUB_REPO_URL:?Must set GITHUB_REPO_URL}
GITHUB_PAT=${GITHUB_PAT:?Must set GITHUB_PAT}
VERSION=${VERSION:-2.325.0}

cd /home/runner

if [ ! -d actions-runner ]; then
  echo "Downloading GitHub Actions runner v${VERSION}"
  curl -L -o actions-runner.tar.gz \
    "https://github.com/actions/runner/releases/download/v${VERSION}/actions-runner-linux-x64-${VERSION}.tar.gz"
  mkdir -p actions-runner && tar xzf actions-runner.tar.gz -C actions-runner
fi

cd actions-runner

./config.sh --unattended \
  --url "$GITHUB_REPO_URL" \
  --token "$(curl -s -X POST -H "Authorization: token ${GITHUB_PAT}" \
    ${GITHUB_REPO_URL}/actions/runners/registration-token | jq -r .token)" \
  --name "$RUNNER_NAME" \
  --work "_work" \
  --labels docker,linux

exec ./run.sh

