#!/usr/bin/env bash
# vim:set ft=bash:

# packages:get
#   Get a list of all of the package files created during the build of the package base from the metadata file and
#   download them from the upstream repository.
#
#   NOTE: As a `get` step in Concourse, everything should be downloaded into the current directory.
#
# repository: The S3 URL prefix of the repository to download the packages to.
function packages:get {
  local repository="${1}"
  local base files release output

  base=$(metadata:base .)
  if test -z "${base}"; then
    log:fatal "The name of the package base not found"
  fi

  declare -a files
  mapfile -t files < <(metadata:files . | tr ',' '\n')

  if [[ ${#files[@]} -eq 0 ]]; then
    log:fatal "No files found for package base" base="${base}"
  fi

  release=$(metadata:release .)
  if test -z "${release}"; then
    log:fatal "Unable to get the package base release" base="${base}"
  fi

  log:info "Downloading package files from the repository" repository="${repository}" base="${base}" \
    release="${release}" files="$(join_by ", " "${files[@]}")"

  for file in "${files[@]}"; do
    # Reject any file names that are not a simple file name with the expected extension, preventing any path traversal
    # or other unexpected file names from being used to download files from the repository by a malicious metadata file.
    if [[ ${file} != "$(basename "${file}")" || ! ${file} =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*\.pkg\.tar\.zst$ ]]; then
      log:fatal "Refusing to process package file with an unexpected name" base="${base}" file="${file}"
    fi

    log:debug "Downloading package file from the repository" repository="${repository}" base="${base}" \
      release="${release}" file="${file}"

    if ! output=$(aws s3 cp "${repository}/${file}" "./${file}" 2>&1); then
      echo "${output}" >&2
      log:fatal "Failed to download package file" repository="${repository}" base="${base}" release="${release}" \
        file="${file}"
    fi

    log:debug "Downloading package file signature from the repository" repository="${repository}" base="${base}" \
      release="${release}" file="${file}.sig"

    if ! output=$(aws s3 cp "${repository}/${file}.sig" "./${file}.sig" 2>&1); then
      echo "${output}" >&2
      log:fatal "Failed to download package file signature" repository="${repository}" base="${base}" \
        release="${release}" file="${file}.sig"
    fi
  done
}

# packages:put
#   Find all of the packages files (and their signatures) created during the build of the package base and upload them
#   to the repository.
#
# repository: The S3 URL prefix of the repository to upload the packages to.
# base: The name of the package base to upload the packages for.
# repository: The S3 URL prefix of the repository to upload the packages to.
# base: The name of the package base to upload the packages for.
function packages:put {
  local repository="${1}" base="${2}"
  local rollback=0 path="packages"
  local output files

  declare -a files
  mapfile -t files < <(find "${path}" -maxdepth 1 -type f -name "*.pkg.tar.zst")

  if [[ ${#files[@]} -eq 0 ]]; then
    log:fatal "No packages found to upload to the repository" base="${base}" path="${path}"
  fi

  log:info "Uploading packages to the repository" repository="${repository}" base="${base}" path="${path}" \
    files="$(join_by ", " "${files[*]}")"

  for file in "${files[@]}"; do
    if ! package:cp "${file}" "${repository}/${file##*/}"; then
      rollback=1
      break
    fi
  done

  if test $rollback -ne 0; then
    # Make sure we delete all the files we have uploaded so far, as we don't want to leave the repository in a
    # half-uploaded state, and, as we have not updated he database, the cleanup job will not trigger.
    for file in "${files[@]}"; do
      package:rm "${dest}/${file##*/}"
    done

    log:fatal "Failed to upload one or more packages" repository="${repository}" base="${base}" path="${path}" \
      files="$(join_by ", " "${files[*]}")"
  fi
}

# package:cp
#   Upload a single package and its signature, if found, to the repository.
#
# src: The path to the package file to upload.
# dest: The S3 URI of the package file to upload to the repository.
function package:cp {
  local src="${1}" dest="${2}"
  local output

  log:debug "Uploading package to the repository" src="${src}" dest="${dest}"

  if ! output=$(aws s3 cp --content-type application/zstd "${src}" "${dest}" 2>&1); then
    echo "${output}" >&2
    log:warning "Failed to upload package" src="${src}" dest="${dest}"
    return 1
  fi

  if [[ -r "${src}.sig" ]]; then
    log:debug "Uploading package signature to the repository" src="${src}.sig" dest="${dest}.sig"

    if ! output=$(aws s3 cp --content-type application/pgp-signature "${src}.sig" "${dest}.sig" 2>&1); then
      echo "${output}" >&2
      log:warning "Failed to upload package signature" src="${src}.sig" dest="${dest}.sig"
      return 1
    fi
  fi
}

# package:rm
#   Remove a single package and its signature, if found, from the repository. We do not care if the package, or its
#   signature, fail to be removed in this case, as the cleanup job will be run again in the future and will attempt to
#   remove it again. Additionally, we may be attempting to remove files that have not yet been uploaded.
#
# dest: The S3 URI of the package file to remove from the repository.
function package:rm {
  local dest="${1}"
  local output

  log:debug "Removing package from the repository" dest="${dest}"

  if ! output=$(aws s3 rm "${dest}" 2>&1); then
    echo "${output}" >&2
    log:warning "Failed to remove the package" dest="${dest}"
  fi

  if ! output=$(aws s3 rm "${dest}.sig" 2>&1); then
    echo "${output}" >&2
    log:warning "Failed to remove the package signature" dest="${dest}.sig"
  fi
}
