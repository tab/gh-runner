# GitHub Self-Hosted Runner

A containerized GitHub Actions runner that can be deployed to run CI/CD workflows for your GitHub repositories. This Docker-based solution provides a secure, scalable way to execute GitHub Actions workflows on your own infrastructure.

## Features

- **Containerized**: Runs in Docker with minimal dependencies
- **Secure**: Non-root execution with limited sudo permissions
- **Multi-architecture**: Supports both AMD64 and ARM64
- **Auto-registration**: Dynamically registers with GitHub using API tokens
- **Graceful cleanup**: Properly removes runner registration on shutdown
- **Persistent work directory**: Mounts work directory for build artifacts

## Quick Start

### Prerequisites

- Docker installed and running
- GitHub Personal Access Token with repository access
- GitHub repository where you want to run workflows

### Running the Runner

1. **Build the container:**
   ```bash
   docker build -t gh-runner .
   ```

2. **Run the container:**
   ```bash
   docker run -d \
     --name my-github-runner \
     -e GITHUB_REPO="owner/repository-name" \
     -e GITHUB_PAT="your_personal_access_token_here" \
     -v /path/to/work:/home/runner/_work \
     gh-runner
   ```

3. **Check the logs:**
   ```bash
   docker logs my-github-runner
   ```

## Environment Variables

### Required

| Variable      | Description                              | Example            |
|---------------|------------------------------------------|--------------------|
| `GITHUB_REPO` | GitHub repository in format "owner/repo" | `myorg/myrepo`     |
| `GITHUB_PAT`  | Personal Access Token with repo access   | `ghp_xxxxxxxxxxxx` |

### Optional

| Variable        | Description            | Default                       |
|-----------------|------------------------|-------------------------------|
| `RUNNER_NAME`   | Name for the runner    | `gh-runner-{hostname}`        |
| `RUNNER_LABELS` | Comma-separated labels | `docker,linux,{architecture}` |

## GitHub Personal Access Token Setup

Your Personal Access Token needs the following permissions:
- `repo` (Full control of private repositories)
- Or `public_repo` (Access public repositories) if only using public repos

To create a token:
1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Generate new token (classic)
3. Select appropriate repository permissions
4. Copy the token and use it as `GITHUB_PAT`

## Docker Compose Example

```yaml
version: '3.8'
services:
  github-runner:
    build: .
    environment:
      - GITHUB_REPO=myorg/myrepo
      - GITHUB_PAT=ghp_xxxxxxxxxxxx
      - RUNNER_NAME=docker-runner-1
      - RUNNER_LABELS=docker,linux,self-hosted
    volumes:
      - ./work:/home/runner/_work
    restart: unless-stopped
```

## Volume Mounts

The runner requires a work directory to be mounted:

```bash
-v /host/path/to/work:/home/runner/_work
```

**Important**: The work directory must be writable by UID 1001:
```bash
sudo chown -R 1001:1001 /host/path/to/work
```

## Architecture

The runner consists of:

1. **Multi-stage Dockerfile**:
   - Downloads GitHub Actions runner (v2.325.0)
   - Downloads Goose database migration tool (v3.24.3)
   - Uses Debian 12.6-slim as runtime base

2. **Entrypoint script**:
   - Handles runner registration with GitHub API
   - Manages graceful shutdown and cleanup
   - Configures runner with proper labels and work directory

3. **Security model**:
   - Runs as non-root user (UID 1001)
   - Limited sudo permissions for package management
   - Isolated container environment

## Troubleshooting

### Runner not appearing in GitHub

1. Check container logs: `docker logs container-name`
2. Verify `GITHUB_REPO` format is correct (`owner/repo`)
3. Ensure Personal Access Token has correct permissions
4. Check if repository exists and token has access

### Permission errors

1. Ensure work directory has correct ownership:
   ```bash
   sudo chown -R 1001:1001 /path/to/work
   ```

### Runner registration fails

1. Verify Personal Access Token is valid and not expired
2. Check if repository name is correct
3. Ensure network connectivity to GitHub API

## Development

### Building locally
```bash
docker build -t gh-runner .
```

### Testing the entrypoint
```bash
docker run --rm -it \
  -e GITHUB_REPO="owner/repo" \
  -e GITHUB_PAT="token" \
  gh-runner
```

### Debugging
```bash
docker run --rm -it \
  -e GITHUB_REPO="owner/repo" \
  -e GITHUB_PAT="token" \
  gh-runner bash
```

## License

See [LICENSE](LICENSE) file for details.
