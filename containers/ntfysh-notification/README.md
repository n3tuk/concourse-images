# ntfy.sh Notification Resource for Concourse

A Concourse custom [resource type][resource] that sends build notifications to an [ntfy.sh](https://ntfy.sh/) topic. It
is based on `dhi.io/debian-base:trixie`.

[resource]: https://concourse-ci.org/implementing-resource-types.html

Because notifications only make sense as a `put`, the resource uses minimal `check`/`in` implementations (the shared
`empty-check`/`empty-in` timestamp scripts) and does its work in `out` (`ntfysh-notification`):

| `/opt/resource` script | Entry point           | Role                                                     |
| ---------------------- | --------------------- | -------------------------------------------------------- |
| `check`                | `empty-check`         | Returns a timestamp-only version.                        |
| `in`                   | `empty-in`            | Echoes back the requested timestamp version.             |
| `out`                  | `ntfysh-notification` | Sends the notification and returns a `sequence` version. |

## Behaviour

The `out` step builds a message from a `type` discriminator and posts it to `<endpoint>/<topic>` with headers (title,
priority, click-through URL to the build, icon). Built-in message types cover the package build/sign/update and
repository update/cleanup events; `type: custom` sends an arbitrary `title`/`message`.

## Configuration

`source`:

| Key        | Required | Default           | Notes                          |
| ---------- | -------- | ----------------- | ------------------------------ |
| `endpoint` | yes      | `https://ntfy.sh` | ntfy.sh base URL.              |
| `topic`    | yes      | —                 | Topic to publish to.           |
| `disable`  | no       | `false`           | When `true`, `out` is a no-op. |

`params` (per `put`):

| Key                | Required              | Notes                                                         |
| ------------------ | --------------------- | ------------------------------------------------------------- |
| `repository`       | yes                   | Repository name.                                              |
| `arch`             | no (`x86_64`)         | Architecture.                                                 |
| `type`             | no (`custom`)         | One of the built-in event types, or `custom`.                 |
| `priority`         | no (`low`)            | `low`/`default`/`normal`/`high`/`urgent`.                     |
| `base`             | depends               | Package base; required by the package/repository event types. |
| `title`, `message` | required for `custom` | Free-text notification body.                                  |

See `examples/kiro-cli.yaml` for `on_success`/`on_failure`/`on_error` notification usage.

## Build and test

```sh
task podman:build:ntfysh-notification   # build as ntfysh-notification:testing
task shellcheck
task hadolint
task bats                                # BATS suite (none yet)
```

The `out` script writes its JSON result to file descriptor 3 and logs to stderr.
