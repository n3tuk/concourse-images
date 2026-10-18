# Arch Linux Repository Cleanup Task for Concourse

A task image (based on `dhi.io/debian-base:trixie`) that removes stale package files from the Cloudflare R2 bucket. Its
single entry point is at `/opt/task/repository-cleanup`.

## Behaviour

1. Extracts the current repository database (provided as the `database` input) and records every package filename it
   references.
2. Lists every `*.pkg.tar.zst` object present under the repository prefix in the bucket.
3. **Safety check:** fails if any package referenced by the database is missing from the bucket (so a stale database can
   never cause newer packages to be deleted).
4. Removes each package file (and its `.sig`) present in the bucket but **not** referenced by the database — i.e.
   superseded versions.

Removal failures are logged as warnings and retried on the next run; a missing referenced package is a fatal error.

## `params` configuration

Unlike the resources, the cleanup task reads its configuration from `params` (environment variables):

| Variable            | Required | Notes                         |
| ------------------- | -------- | ----------------------------- |
| `endpoint`          | yes      | S3/R2 endpoint URL.           |
| `region`            | yes      | AWS region.                   |
| `bucket`            | yes      | Bucket name.                  |
| `repository`        | yes      | Repository name (e.g. `aur`). |
| `arch`              | yes      | Architecture (e.g. `x86_64`). |
| `access_key_id`     | yes      | **Sensitive.**                |
| `secret_access_key` | yes      | **Sensitive.**                |

It takes the repository `database` as an **input**. See `examples/repository-cleanup.yaml` for a complete scheduled
pipeline.

## Build and test

```sh
task podman:build:repository-cleanup   # build as repository-cleanup:testing
task shellcheck
task hadolint
task bats                               # BATS suite (none yet)
```

A `trap failure ERR` ensures that any error in the cleanup produces a single structured fatal log line rather than an
opaque partial failure.
