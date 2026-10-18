#!/usr/bin/env bash
# vim:set ft=bash:

function ntfysh:url:pipeline {
  printf '%s/teams/%s/pipelines/%s' \
    "${ATC_EXTERNAL_URL}" \
    "${BUILD_TEAM_NAME}" \
    "${BUILD_PIPELINE_NAME}"
}

function ntfysh:url:job {
  printf '%s/teams/%s/pipelines/%s/jobs/%s/builds/%s' \
    "${ATC_EXTERNAL_URL}" \
    "${BUILD_TEAM_NAME}" \
    "${BUILD_PIPELINE_NAME}" \
    "${BUILD_JOB_NAME}" \
    "${BUILD_NAME}"
}

function ntfysh:send {
  local endpoint="${1}" sequence="${2}" priority="${3}" title="${4}" message="${5}" url="${6}"
  local headers

  log:info "Sending message notification" endpoint="${endpoint}" sequence="${sequence}" priority="${priority}" title="${title}"

  headers=(
    --header "X-Sequence-ID: ${sequence}"
    --header "Title: ${title}"
    --header "Icon: https://assets.n3t.uk/icons/concourse-256x256.png"
    --header "Priority: ${priority}"
    --header "Click: ${url}"
    --header "Actions: view, View the Pipeline, ${url}"
    --header "Markdown: yes"
  )

  if ! curl --fail --silent --show-error \
    "${headers[@]}" \
    --data "${message}" \
    "${endpoint}"; then
    log:fatal "Failed to send message notification" endpoint="${endpoint}" sequence="${sequence}" priority="${priority}" title="${title}"
  fi
}

function ntfysh:message:build:error {
  local repository="${1}" package="${2}" arch="${3}"

  cat <<EOF | tr '\n' ' '
Concourse is reporting an **error** when attempting to run the pipeline job to build \`${package}\` for the
\`${repository}/${arch}\` Arch Linux Repository. Please go to the pipeline and review the \`build\` job logs for more
information.
EOF
}

function ntfysh:message:build:failure {
  local repository="${1}" package="${2}" arch="${3}"

  cat <<EOF | tr '\n' ' '
Concourse is reporting a **failure** in the pipeline when building \`${package}\` for the \`${repository}/${arch}\`
Arch Linux Repository. Please go to the pipeline and review the \`build\` task logs for more information.
EOF
}

function ntfysh:message:sign:failure {
  local repository="${1}" package="${2}" version="${3}"

  cat <<EOF | tr '\n' ' '
Concourse is reporting a **failure** in the pipeline when signing \`${package}\` \`v${version}\` for the
\`${repository}/${arch}\` Arch Linux Repository. Please go to the pipeline and review the \`build\` task logs for more
information.
EOF
}

function ntfysh:message:update:success {
  local repository="${1}" arch="${2}" package="${3}" version="${4}"

  cat <<EOF | tr '\n' ' '
Concourse has successfully built, signed, and updated the \`${repository}/${arch}\` Arch Linux Repository with
\`${package}\` \`v${version}\`.
EOF
}

function ntfysh:message:update:failure {
  local repository="${1}" arch="${2}" package="${3}" version="${4}"

  cat <<EOF | tr '\n' ' '
Concourse is reporting a **failure** in the pipeline when updating the \`${repository}\` Arch Linux repository database
with \`${package}\` \`v${version}\`. Please go to the pipeline and review the \`update\` job logs for more information.
EOF
}

function ntfysh:message:update:error {
  local repository="${1}" arch="${2}" package="${3}" version="${4}"

  cat <<EOF | tr '\n' ' '
Concourse is reporting an **error** in the pipeline when updating the \`${repository}/${arch}\` Arch Linux repository
database with \`${package}\` \`v${version}\`. Please go to the pipeline and review the \`update\` job logs for more
information.
EOF
}

function ntfysh:message:cleanup:failure {
  local repository="${1}" arch="${2}"

  cat <<EOF | tr '\n' ' '
Concourse is reporting that the cleanup of the \`${repository}/${arch}\` Arch Linux Repository packages has **failed**.
Please go to the pipeline and review the \`cleanup\` logs for more information.
EOF
}
