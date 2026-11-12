# Pterodactyl-Java-Eggs

## Overview

This project contains Docker images for use with Pterodactyl. It includes various versions of Java, ensuring that the images work on different platforms such as `linux/amd64` and `linux/arm64`.

## Directory Structure

- `.github/workflows/Java.yml`: GitHub Actions workflow for building and publishing the Java Docker images.
- `java/entrypoint.sh`: Entrypoint script executed when the Java container starts.
- `java/21/Dockerfile`: Dockerfile for Java 21.

## Docker Images

The Docker images are automatically built and pushed to the GitHub Container Registry (`ghcr.io`). The tags of the images follow the schema `java_<version>`.

## Java Build Runner Egg

`egg-java-build-runner.json` clones a Maven project, builds it and starts the resulting JAR.
The checkout in `/home/container/repo` is kept between starts: the egg fetches, rebuilds and copies
`target/$RUN_FILE` to `/home/container/`. If fetching or building fails, the last successfully
built JAR is started instead, so a GitHub outage or an expired credential no longer takes the
bot down.

| Variable | Default | Purpose |
|---|---|---|
| `GITHUB_REPO_URL` | | `https://github.com/owner/repo` or `git@github.com:owner/repo` |
| `BRANCH` | `main` | Branch to deploy |
| `RUN_FILE` | | JAR name inside `target/` |
| `GIT_AUTH` | `auto` | `token`, `deploy_key`, `none` or `auto` (token if `ACCESS_TOKEN` is set, else deploy key if one exists, else anonymous) |
| `USERNAME` / `ACCESS_TOKEN` | *(empty)* | HTTPS credentials for `GIT_AUTH=token` |
| `AUTO_UPDATE` | `true` | `false` starts the JAR already built without fetching |
| `DEPLOY_REF` | *(empty)* | Tag or commit to deploy instead of the head of `BRANCH` |

Existing servers keep working: tokens are still accepted, but they are sent as an HTTP header and
are no longer written into the remote URL.

### Recommended: read-only deploy keys

1. Set `GIT_AUTH` to `deploy_key` and start the server.
2. The console prints a new public key (`ssh-ed25519 … pelican-<server-uuid>`), stored in
   `/home/container/.ssh/deploy_key`.
3. Add it to the repository under **Settings → Deploy keys** with *Allow write access* off.
4. Restart the server.

A deploy key can read exactly one repository, so no account-wide token has to live on the server.
GitHub's SSH host key is pinned.

### Changing the startup command

Edit `egg-startup.sh` and run `python3 scripts/build-egg-startup.py`, which writes it into the egg
while keeping the panel export format.

## Usage

### Running a Docker Image

To run a Docker image, use the following command:

```sh
docker run -it ghcr.io/coho04/pterodactyl-docker-images:java_<version>
```