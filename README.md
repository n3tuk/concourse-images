# concourse-images (Concourse CI Task/Resource Images)

The `concourse-images` repository contains the container images used by the `aur-pipelines` Concourse CI pipeline
generator. These images are used to build and run different stages of the pipeline, including building AUR packages,
signing them, uploading them to a Cloudflare R2 bucket, and cleaning up old packages from the repository.

## Purpose

The project automates the lifecycle of an [Arch Linux](https://archlinux.org/) package repository hosted on Cloudflare
R2 (an S3-compatible object store). For each AUR package base, a Concourse pipeline uses these images to:

1. **Build** the package from its `PKGBUILD`/`.SRCINFO` with `makepkg` (`arch-builder`).
2. **Sign** the resulting package files with a GPG key (`arch-builder`).
3. **Publish** the package files and a per-base `metadata.json` to R2 (`repository-package` resource).
4. **Update** the repository database (`.db.tar.gz`) via `repo-add` and publish it (`repository-database` resource and
   the `arch-builder` update task).
5. **Clean up** package files in the bucket that the current database no longer references (`repository-cleanup`).
6. **Notify** on success or failure through [ntfy.sh](https://ntfy.sh/) (`ntfysh-notification`).

There is no compiled application here — all behaviour is implemented as Bash scripts (in `scripts/`) packaged into the
container images (in `containers/`). The shared library functions live in `scripts/lib/` and the container entry points
in `scripts/bin/`.

## Images

| Image                 | Kind     | Purpose                                                        |
| --------------------- | -------- | -------------------------------------------------------------- |
| `arch-builder`        | Task     | Build, sign, and database-update AUR packages.                 |
| `repository-package`  | Resource | Track and transfer per-package-base versions and files in R2.  |
| `repository-database` | Resource | Track and transfer the Arch repository database object in R2.  |
| `repository-cleanup`  | Task     | Remove bucket packages not referenced by the current database. |
| `ntfysh-notification` | Resource | Send pipeline notifications to ntfy.sh.                        |

Each image has its own `README.md` under `containers/<name>/` describing its contract (the `source`/`params`/`version`
fields it consumes), and how to build and test it.

## Repository layout

- `containers/<name>/` — one `Dockerfile` per image, plus any `assets/` copied into it.
- `scripts/bin/` — container entry points (resources expose `check`/`in`/`out`; tasks are single executables).
- `scripts/lib/` — Bash libraries sourced by the entry points (logging, payload parsing, S3/metadata/database helpers).
- `common/assets/` — assets shared across images.
- `examples/` — example Concourse pipelines showing the `source` and `params` payloads (not committed).
- `.task/`, `Taskfile.yaml` — the Task-based development, lint, build, and analysis workflow.
- `AGENTS.md` — a concise map of the repository for AI assistants.
- `REVIEW.md`, `REVIEW-*.patch` — the standing code-review findings and ready-to-apply fixes.

## Local development

The repository uses [Task](https://taskfile.dev/) to build and validate the images. Install Podman, Hadolint, the Snyk
CLI, and Task before running the development workflow. The `task` command will check that the applications is requires
are installed before calling them, and will fail if any are missing.

Authenticate the Snyk CLI with `snyk auth`, or provide a token through the `SNYK_TOKEN` environment variable. The local
development tooling uses `podman` for the building and management of the container images. If you are using the rootless
configuration in Podman, you will need to enable the socket service and point the `DOCKER_HOST` environment variable at
it so that Snyk can communicate with Podman:

On Linux with rootless Podman, start its Docker-compatible API socket and point Snyk at it before scanning:

```sh
$ systemctl --user start podman.socket

# Bash
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/podman/podman.sock"
# Fish
set -Ux DOCKER_HOST "unix://${XDG_RUNTIME_DIR}/podman/podman.sock"
```

Run `task develop` to lint, build, and scan all container images. Also run `task snyk` to perform a static analysis of
any container images built. The Snyk scan uses each image's local `:testing` tag and fails when Snyk finds a
vulnerability; scan results depend on the current Snyk vulnerability database and the packages available from the
image's base repositories.

## GitHub Actions

The GitHub Actions workflow has three stages:

1. It discovers every directory below `containers/` that contains a `Dockerfile` and creates the build matrix.
2. It runs `task lint` and `task analyse` with the repository's pinned tool versions.
3. It builds each matrix entry for `linux/amd64`, monitors and tests the image with Snyk, and publishes it when the
   workflow runs on `main`.

Pull requests run discovery, quality checks, and image builds without publishing. Snyk runs when `SNYK_TOKEN` is
available; fork pull requests cannot receive repository secrets and therefore skip the Snyk steps. Builds on `main`
require `SNYK_TOKEN` and publish images to GHCR with both `sha-<full-commit-sha>` and `latest` tags. Use the immutable
`sha-<full-commit-sha>` tag when referring to an image from Concourse.

## Contributing

Use `task develop` to lint, build, and scan locally before opening a pull request. See [AGENTS.md](AGENTS.md) for a map
of the repository, the script conventions, and the full set of `task` commands.

## Authors

- Jonathan Wright (<jon@than.io>)

## Licence

[MIT](LICENSE)
