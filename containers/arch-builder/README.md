# Arch Linux Builder Task for Concourse

A task image (based on `archlinux:base-devel`) that builds, signs, and database-registers Arch Linux AUR packages inside
a Concourse pipeline. Unlike the resource images, this image is used directly as a Concourse `task` and ships three
entry points, selected by the task's `run.path`:

| Entry point     | `run.path`              | Purpose                                                                                                                     |
| --------------- | ----------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| build (default) | `/usr/local/bin/build`  | Run `makepkg` against the `aur` input and save the built `*.pkg.tar.zst` files (and `.SRCINFO`) into the `packages` output. |
| sign            | `/usr/local/bin/sign`   | Import the signing key and produce a detached `.sig` for every built package, then remove the key.                          |
| update          | `/usr/local/bin/update` | Add the signed packages to the repository database with `repo-add`.                                                         |

## Image contents

- Fully initialised Arch keyring plus this project's repository public key, trust-signed so `pacman` can verify packages
  served from the project's own repository (configured in `assets/pacman.conf` + `assets/aur`).
- A non-root `builder` user with passwordless `sudo` (`assets/sudoers`) so `makepkg` can install build dependencies.
- The `scripts/lib` libraries at `/usr/local/lib` and the three entry points in `/usr/local/bin`.

## Inputs, outputs, and parameters

The entry points consume Concourse task **inputs/outputs** and `params`:

- `build` — input `aur` (the cloned AUR git resource, hard-coded path `aur`), output `packages`.
- `sign` — operates on the `packages` directory. Requires `params`: `gpg_fingerprint`, `gpg_private_key` (sensitive),
  `gpg_passphrase` (sensitive).
- `update` — inputs `packages` and `database`; requires `params`: `repository` (the repository name, used to locate
  `database/<repository>.db.tar.gz`).

See `examples/kiro-cli.yaml` for a complete pipeline using all three steps.

## Build and test

From the repository root, using [Task](https://taskfile.dev):

```sh
task podman:build:arch-builder   # build this image as arch-builder:testing
task shellcheck                  # static-analyse the Bash entry points and libraries
task hadolint                    # lint the Dockerfile
task bats                        # run the BATS suite (none yet)
```

`task podman:build:arch-builder` runs `hadolint` and `shellcheck` first and rebuilds only when the Dockerfile, its
assets, the relevant `scripts/bin/arch-builder-*` entry points, or `scripts/lib` change.
