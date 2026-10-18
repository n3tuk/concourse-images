# Arch Linux Repository Package Resource for Concourse

A Concourse [custom resource type](https://concourse-ci.org/implementing-resource-types.html) that tracks and transfers
the package files for a single Arch Linux **package base** stored in a Cloudflare R2 (S3-compatible) bucket. It is based
on `dhi.io/debian-base:trixie` and exposes the standard `check`/`in`/`out` scripts at `/opt/resource/`.

## Behaviour

- **check** (`repository-package-check`) — reads the package base's `metadata.json` from the bucket and reports its
  current `release` as the available version.
- **in** (`repository-package-in`) — downloads the `metadata.json`, then every package file and its `.sig` listed in
  that metadata, into the resource directory.
- **out** (`repository-package-out`) — uploads the built package files and signatures from the `packages` directory,
  regenerates and uploads `metadata.json`, and emits the resulting `release` and metadata.

The version tracked by this resource is the package `release` (`pkgver-pkgrel`).

## `source` configuration

| Key                 | Required | Default | Notes                                     |
| ------------------- | -------- | ------- | ----------------------------------------- |
| `endpoint`          | yes      | —       | S3/R2 endpoint URL.                       |
| `region`            | no       | `weur`  | AWS region.                               |
| `bucket`            | yes      | —       | Bucket name.                              |
| `repository`        | yes      | —       | Repository name (e.g. `aur`).             |
| `arch`              | yes      | —       | Architecture (e.g. `x86_64`).             |
| `base`              | yes      | —       | Package base name.                        |
| `access_key_id`     | yes      | —       | **Sensitive.**                            |
| `secret_access_key` | yes      | —       | **Sensitive.**                            |
| `disable`           | no       | `false` | When `true`, `check` reports no versions. |

Objects are addressed under `s3://<bucket>/<repository>/os/<arch>/`.

## Build and test

```sh
task podman:build:repository-package   # build as repository-package:testing
task shellcheck
task hadolint
task bats                               # BATS suite (none yet)
```

The resource scripts write their JSON result to file descriptor 3 and send all logging to stderr; a failure trap still
emits a valid (empty) JSON document so Concourse always receives well-formed output.
