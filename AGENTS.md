# AGENTS.md

Concise orientation for AI assistants (Kiro, Copilot, etc.) working in this repository. Read this before exploring; it
is maintained to reduce the need to re-read every file.

## What this repository is

`concourse-images` builds the container images used by the `aur-pipelines` Concourse CI pipeline generator. The images
implement Concourse **resource types** and **tasks** that build Arch Linux AUR packages, sign them, publish them to a
Cloudflare R2 (S3-compatible) bucket, maintain the Arch repository database, clean up old packages, and send ntfy.sh
notifications.

There is **no application code** — the logic is Bash scripts packaged into container images. Tests (BATS) are planned
but not yet written; do not add tests unless asked.

## Layout

```text
containers/<name>/Dockerfile    One image per directory; built/tagged <name>:testing locally.
containers/<name>/README.md      Purpose + build/test for that image.
containers/<name>/assets/        Files COPYed into the image (pacman.conf, sudoers, repo pubkey…).
common/assets/                   Shared image assets (apt config).
scripts/bin/<entrypoint>         Container entrypoints. Resource types expose check/in/out
                                 (symlinked to /opt/resource/{check,in,out}); tasks are single
                                 executables (e.g. /usr/local/bin/build).
scripts/lib/*.sh                 Sourced helper libraries (see "Libraries" below).
examples/                        Example Concourse pipelines (NOT committed; show source/params).
.task/*.yaml                     Taskfile includes (lint, build, analyse, test, podman…).
Taskfile.yaml                    Entry Taskfile. `task develop` is the main workflow.
REVIEW.md, REVIEW-*.patch        Standing code-review findings and ready-to-apply fixes.
```

## Entry points (scripts/bin)

| Script                               | Role                                              | Container           |
| ------------------------------------ | ------------------------------------------------- | ------------------- |
| `arch-builder-build`                 | Task: `makepkg` the AUR package base              | arch-builder        |
| `arch-builder-sign`                  | Task: GPG-sign built packages                     | arch-builder        |
| `arch-builder-update`                | Task: `repo-add` into the repo database           | arch-builder        |
| `repository-package-{check,in,out}`  | Resource: package base versions in R2             | repository-package  |
| `repository-database-{check,in,out}` | Resource: repo database object in R2              | repository-database |
| `empty-{check,in,out}`               | Minimal timestamp resource (used by ntfysh image) | ntfysh-notification |
| `ntfysh-notification`                | Resource `out`: send a notification               | ntfysh-notification |
| `repository-cleanup`                 | Task: delete packages not referenced by the DB    | repository-cleanup  |

## Libraries (scripts/lib)

- `common.sh` — sources `check.sh`, `log.sh`, `output.sh`; defines `join_by`. Entry point for libs.
- `log.sh` — structured logfmt logging to **stderr** plus RFC5424 via `logger`. Levels:
  `log:debug|info|warning|error|fatal`. `log:fatal` prints at `crit` and `exit 1`.
- `check.sh` — `check:variables` / `check:commands` (fatal if missing); `name:sensitive` suffix suppresses value
  logging.
- `output.sh` — `output:variable(s)` debug-logs variable presence/value (respects sensitivity).
- `payload.sh` — reads the Concourse JSON payload from stdin; `payload:source|params|version <key>`.
- `metadata.sh` — read/write the per-package-base `metadata.json` in R2.
- `packages.sh` — download/upload package files + signatures to R2.
- `database.sh` — head/get/extract/update/put the Arch repo DB (`.db.tar.gz` / `.files.tar.gz`).
- `build.sh` — `makepkg`, save artefacts, GPG import/sign/cleanup.
- `ntfysh.sh` — build the notification URL/message bodies and POST to ntfy.sh.
- `sign.sh`, `update.sh` — currently empty placeholders.

## Conventions (follow these when editing)

- Every entry point starts `set -euo pipefail` and `#!/usr/bin/env bash` + `# vim:set ft=bash:`.
- Resource scripts redirect: `exec 3>&1; exec 1>&2` — **the JSON result goes to fd 3**, all logging to stderr. A
  `trap <emit-fallback-JSON> ERR` must guarantee valid JSON on stdout even on failure.
- Library functions are namespaced with `:` (e.g. `database:put`, `payload:source`).
- Functions declare all locals on the first line(s); pass positional args in a documented order. The canonical S3 source
  order is `endpoint region bucket repository arch [base]`.
- Comments only where intent is non-obvious; keep them accurate.
- Values originating from `PKGBUILD`/`.SRCINFO`/payloads are **untrusted** — never interpolate them into `jq` programs,
  `printf` format strings, JSON built by hand, or shell paths without validation.
- Logging: use the existing `log:*` helpers; emit logfmt key=value pairs, never bare `echo` to stderr for structured
  messages.

## Build / test / lint

Tasks (via [Task](https://taskfile.dev)); run `task --list` for all:

```sh
task develop        # lint + build + snyk + analyse (the main loop; supports --watch)
task lint           # prettier, markdownlint, yamllint, hadolint, shfmt
task build          # podman build every image as <name>:testing
task podman:build:<name>   # build one image
task analyse        # shellcheck, check-jsonschema, actionlint, zizmor
task snyk           # Snyk container scan of built :testing images
task test           # BATS suite (none yet)
```

Shellcheck runs with `--external-sources --source-path=scripts/lib --shell=bash`. Scripts source libraries at runtime
via an exported `LIB_DIR`.

## Runtime model

- Images are published to `ghcr.io/n3tuk/concourse/<name>`; pipelines pin by immutable `sha-<commit>` tag (local/dev
  uses `:testing`).
- R2 credentials and GPG key material arrive via Concourse `source`/`params`; they are exported as `AWS_*` env vars for
  the AWS CLI and must never be logged.
- Base images: Arch (`archlinux:base-devel`) for the builder; `dhi.io/debian-base:trixie` for the Debian-based
  resources/tasks.

## When reviewing

`REVIEW.md` is the current review backlog with stable IDs and `REVIEW-NN.patch` files. Prefer referencing/extending it
over duplicating findings. Highest-risk themes: untrusted `PKGBUILD` data, GPG secret handling, and always emitting
valid JSON on stdout for Concourse.
