# Arch Linux Repository Database Resource for Concourse

A Concourse [custom resource type](https://concourse-ci.org/implementing-resource-types.html) that tracks and transfers
the Arch Linux repository **database** object (`<repository>.db.tar.gz` and its companion `<repository>.files.tar.gz`)
stored in a Cloudflare R2 (S3-compatible) bucket. It is based on `dhi.io/debian-base:trixie` and exposes the standard
`check`/`in`/`out` scripts at `/opt/resource/`.

## Behaviour

- **check** (`repository-database-check`) — confirms the database object exists and reports its current `ETag` as the
  version. This lets downstream jobs trigger whenever the database changes.
- **in** (`repository-database-in`) — downloads the database and files archives (recreating the `.db`/`.files` symlink
  names locally), guarded by the requested `ETag`.
- **out** (`repository-database-out`) — uploads the updated database (and the extension-less symlink copies, since S3
  has no symlinks), waits for R2 to become consistent, and emits the new `ETag`.

The version tracked by this resource is the database object's `ETag`.

## `source` configuration

| Key                 | Required | Default | Notes                                     |
| ------------------- | -------- | ------- | ----------------------------------------- |
| `endpoint`          | yes      | —       | S3/R2 endpoint URL.                       |
| `region`            | no       | `weur`  | AWS region.                               |
| `bucket`            | yes      | —       | Bucket name.                              |
| `repository`        | yes      | —       | Repository name (e.g. `aur`).             |
| `arch`              | yes      | —       | Architecture (e.g. `x86_64`).             |
| `access_key_id`     | yes      | —       | **Sensitive.**                            |
| `secret_access_key` | yes      | —       | **Sensitive.**                            |
| `disable`           | no       | `false` | When `true`, `check` reports no versions. |

Objects are addressed under `s3://<bucket>/<repository>/os/<arch>/`.

## Build and test

```sh
task podman:build:repository-database   # build as repository-database:testing
task shellcheck
task hadolint
task bats                                # BATS suite (none yet)
```

The resource scripts write their JSON result to file descriptor 3 and send all logging to stderr; a failure trap still
emits a valid (empty) JSON document so Concourse always receives well-formed output.
