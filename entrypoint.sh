#!/bin/bash
set -euo pipefail

RUNNER_NAME=${RUNNER_NAME:-gh-runner}
GITHUB_REPO=${GITHUB_REPO:?Must set GITHUB_REPO}
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

echo "Registering runner to ${GITHUB_REPO}"

TOKEN=$(curl -s -X POST \
  -H "Authorization: token ${GITHUB_PAT}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${GITHUB_REPO}/actions/runners/registration-token" \
  | jq -r .token)

./config.sh --unattended \
  --url "https://github.com/${GITHUB_REPO}" \
  --token "$TOKEN" \
  --name "$RUNNER_NAME" \
  --work "_work" \
  --labels docker,linux

exec ./run.sh
