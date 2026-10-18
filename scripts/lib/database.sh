#!/usr/bin/env bash
# vim:set ft=bash:

function database:exists {
  local bucket="${1}" database="${2}" etag="${3:-}"
  local arguments output

  declare -a arguments=(
    head-object
    --bucket "${bucket}"
    --key "${database}"
  )

  log:info "Checking for repository database" bucket="${bucket}" database="${database}" etag="${etag:-(none)}"

  if test -n "${etag}"; then
    arguments+=(--if-match "${etag}")
  fi

  if ! output=$(aws s3api "${arguments[@]}" 2>&1); then
    if grep -q "Not Found" <<<"${output}"; then
      log:debug "Repository database does not exist" bucket="${bucket}" database="${database}" etag="${etag:-(none)}"
      return 1
    else
      echo "${output}" >&2
      log:warning "Failed to retrieve repository database metadata" bucket="${bucket}" database="${database}" \
        etag="${etag:-(none)}"
      return 1
    fi
  fi

  return 0
}

function database:etag {
  local bucket="${1}" database="${2}"
  local metadata

  log:info "Retrieving repository database metadata" bucket="${bucket}" database="${database}"

  metadata=$(aws s3api head-object --bucket "${bucket}" --key "${database}" 2>/dev/null || echo "{}")
  jq --raw-output '.ETag // "none"' <<<"${metadata}" 2>/dev/null | tr -d '"'
}

function database:get {
  local database="${1}"
  local arguments files output

  # We only need to download one version of each of the files as normally they are symlinked on the filesystem.
  declare -a sources=("${database}" "${database%%.db.tar.gz}.files.tar.gz")

  log:info "Downloading the repository database" database="${database}"

  for source in "${sources[@]}"; do
    local destination="${source##*/}"

    log:debug "Downloading the repository database file" source="${source}" destination="${destination}" \
      symlink="${destination%%.tar.gz}"

    # Capture the AWS error so a failure surfaces as a structured fatal (consistent with the other
    # download helpers) rather than aborting with a raw stack trace under set -e.
    if ! output=$(aws s3 cp "${source}" "${destination}" 2>&1); then
      echo "${output}" >&2
      log:fatal "Failed to download repository database file" source="${source}" destination="${destination}"
    fi

    ln -sf "${destination}" "${destination%%.tar.gz}"
  done
}

function database:extract {
  local database="${1}"

  log:info "Extracting Repository database" database="${database}" destination="${database%/*}/db"

  if ! test -f "${database}"; then
    log:warning "Repository database file does not exist" database="${database}"
    return 1
  fi

  mkdir -p "${database%/*}/db"
  tar xzf "${database}" -C "${database%/*}/db"
}

function database:update {
  local database="${1}" packages="${2}"
  local files

  declare -a files
  mapfile -t files < <(find "${packages}" -maxdepth 1 -type f -name "*.pkg.tar.zst")

  if test "${#files[@]}" -eq 0; then
    log:warning "No packages found" database="${database}" packages="${packages}" \
      extension=".pkg.tar.zst"
    return 0
  fi

  log:info "Updating the repository database" database="${database}" \
    files="$(join_by ", " "${files[@]}")"

  repo-add --prevent-downgrade --include-sigs "${database}" "${files[@]}"
}

function database:put {
  local database="${1}" repository="${2}"
  local arguments

  log:info "Uploading repoistory database" database="${database}" repository="${repository}"

  declare -a sources=("${database}" "${database%%.db.tar.gz}.files.tar.gz")

  for source in "${sources[@]}"; do
    destination="${repository}/${source##*/}"

    log:debug "Uploading repository database file" source="${source}" destination="${destination}"

    # Upload the same file twice, including once without the original .tar.gz extension, and as repo-add created a
    # symlink on the filesystem, but symlinks are not supported in S3, also upload the same file without a .tar.gz
    # extension to ensure that the file is available for retrieval, as if it were a symlink.
    aws s3 cp --content-type application/gzip "${source}" "${destination}"
    aws s3 cp --content-type application/gzip "${source}" "${destination%%.tar.gz}"
  done
}
