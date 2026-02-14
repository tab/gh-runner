# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a GitHub Self-Hosted Runner implementation using Docker containers. The project creates a containerized GitHub Actions runner that can be deployed to run CI/CD workflows for a specific GitHub repository.

## Architecture

The project consists of three main components:

1. **Multi-stage Dockerfile**: Uses Alpine Linux for downloading dependencies and Debian 12.6-slim as runtime
   - Downloads GitHub Actions runner binary (version 2.325.0)
   - Downloads Goose database migration tool (v3.24.3)
   - Sets up a non-root `runner` user with limited sudo permissions

2. **Entrypoint script** (`entrypoint.sh`): Bash script that handles runner lifecycle
   - Registers the runner with GitHub using API tokens
   - Handles graceful shutdown and cleanup
   - Configures runner with repository URL, name, labels, and work directory

3. **Container orchestration**: Designed to be deployed as a container with environment variables

## Key Environment Variables

Required:
- `GITHUB_REPO`: The GitHub repository in format "owner/repo"
- `GITHUB_PAT`: Personal Access Token with repository access

Optional:
- `RUNNER_NAME`: Name for the runner (defaults to "gh-runner-{hostname}")
- `RUNNER_LABELS`: Comma-separated labels (defaults to "docker,linux,{architecture}")

## Development Commands

### Building the container
```bash
docker build -t gh-runner .
```

### Running the container
```bash
docker run -d \
  -e GITHUB_REPO="owner/repo" \
  -e GITHUB_PAT="your_token_here" \
  -v /path/to/work:/home/runner/_work \
  gh-runner
```

### Development workflow
- Edit `entrypoint.sh` for runner logic changes
- Edit `Dockerfile` for dependency or environment changes  
- Test locally with docker build and run commands

## Architecture Notes

- The runner uses GitHub's REST API to obtain registration and removal tokens dynamically
- Work directory is mounted as a volume to persist build artifacts
- Runner automatically removes itself from GitHub on container shutdown
- Security: Runs as non-root user (UID 1001) with minimal sudo permissions
- Supports both amd64 and arm64 architectures
- Uses multi-stage builds to minimize final image size