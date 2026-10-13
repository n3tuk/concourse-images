#!/usr/bin/env bash
# vim:set ft=bash:

# metadata:get
#   Download the metadata artifact for the package base from the repository and save it locally so that we can interact
#   with the packages in the repository, such as dopwnloading them and adding them to the package database.
#
#   NOTE: As a `get` step in Concourse, everything should be downloaded into the current directory.
#
# repository: The S3 URL of the repository to upload the packages to.
# base: The name of the package base to upload the packages for.
# path: The path to the directory where the metadata.json file should be saved. Defaults to "." (the current directory)
function metadata:get {
  local repository="${1}" base="${2}" path="${3:-.}"

  if test -f "${path}/metadata.json"; then
    log:info "Using existing package base metadata" base="${base}" path="${path}" file="metadata.json"
    return
  fi

  log:info "Getting package base metadata from the repository" base="${base}" source="${repository}/${base}.json" \
    path="${path}" file="metadata.json"

  if ! output=$(aws s3 cp "${repository}/${base}.json" "${path}/metadata.json" 2>&1); then
    echo "${output}" >&2
    log:fatal "Failed to get the package base metadata" base="${base}" source="${repository}/${base}.json" \
      path="${path}" file="metadata.json"
  fi
}

# metadata:put
#   Using the .SRCINFO file, and the files that have been built, build a metadata artifact which can be uploaded to the
#   registry to allow future checks against, processing, and downloads of, the packages.
#
# repository: The S3 URL of the repository to upload the packages to.
# base: The name of the package base to upload the packages for.
# arch: The architecture of the package base to upload the packages for. Defaults to "x86_64".
function metadata:put {
  local repository="${1}" base="${2}" arch="${3:-x86_64}"
  local path="packages"
  local description version release packages files output

  if ! test -r "${path}/.SRCINFO"; then
    log:fatal "Missing .SRCINFO file" base="${base}" path="${path}" file=".SRCINFO"
  fi

  description=$(cat "${path}/.SRCINFO" | grep -E '^\s?pkgdesc\s?=' | head -n 1 | awk -F = '{print $2}' | sed -e 's/^\s*//g')
  version=$(cat "${path}/.SRCINFO" | grep -E '^\s?pkgver\s?=' | awk -F = '{print $2}' | tr -d '[:space:]')
  release=$(cat "${path}/.SRCINFO" | grep -E '^\s?pkgrel\s?=' | awk -F = '{print $2}' | tr -d '[:space:]')

  declare -a packages
  mapfile -t packages < <(cat "${path}/.SRCINFO" | grep -E '^pkgname\s?=' | awk -F = '{print $2}' | tr -d '[:space:]')

  if [[ ${#packages[@]} -eq 0 ]]; then
    log:fatal "No packages listed in the .SRCINFO" base="${base}" path="${path}" file=".SRCINFO"
  fi

  declare -a files
  mapfile -t files < <(find "${path}" -maxdepth 1 -type f -name "*.pkg.tar.zst" -printf "%P\n")

  if [[ ${#files[@]} -eq 0 ]]; then
    log:fatal "No files found to process" base="${base}" path="${path}" extension=".pkg.tar.zst"
  fi

  log:info "Genetating package base metadata for the repository" repository="${repository}" base="${base}" \
    description="${description}" version="${version}" release="${release}" arch="$(join_by ", " "${arch[*]}")" \
    packages="$(join_by ", " "${packages[*]}")" files="$(join_by ", " "${files[*]}")" path="${path}"

  cat <<EOF >"${path}/metadata.json"
{
  "version": 1,
  "base": "${base}",
  "release": "${version}-${release}",
  "description": "${description}",
  "packages": ["$(join_by '", "' "${packages[@]}")"],
  "arch": "${arch}",
  "files": ["$(join_by '", "' "${files[@]}")"]
}
EOF

  cat "${path}/metadata.json" | jq --compact-output

  if ! output=$(aws s3 cp "${path}/metadata.json" "${repository}/${base}.json" 2>&1); then
    echo "${output}" >&2
    log:fatal "Failed to upload package base metadata" path="${path}" file="metadata.json" \
      destination="${repository}/${base}.json"
  fi
}

# metadata:check
#   Check that the package base metadata file exists and is readable.
#
# path: The path to the directory where the metadata.json file is saved.
function metadata:check {
  local path="${1:-packages}"

  if ! test -r "${path}/metadata.json"; then
    log:warning "Missing package base metadata file" path="${path}" file="metadata.json"
    return 1
  fi

  return 0
}

# metadata:base
#   Extract and return the name from the package base metadata file.
#
# path: The path to the directory where the metadata.json file is saved. Defaults to "packages".
function metadata:base {
  local path="${1:-packages}"

  metadata:check "${path}" || return 1
  cat "${path}/metadata.json" | jq --raw-output '.base // ""'
}

# metadata:release
#   Extract and return the combined package version and release (i.e. the release) from the package base metadata file.
#
# path: The path to the directory where the metadata.json file is saved. Defaults to "packages".
function metadata:release {
  local path="${1:-packages}"

  metadata:check "${path}" || return 1
  cat "${path}/metadata.json" | jq --raw-output '.release // ""'
}

# metadata:description
#   Extract and return the package description from the package base metadata file.
#
# path: The path to the directory where the metadata.json file is saved. Defaults to "packages".
function metadata:description {
  local path="${1:-packages}"

  metadata:check "${path}" || return 1
  cat "${path}/metadata.json" | jq --raw-output '.description // ""'
}

# metadata:packages
#   Extract and return a comma-separated list of all packages generated from this package base from the package base
#   metadata file
#
# path: The path to the directory where the metadata.json file is saved. Defaults to "packages".
function metadata:packages {
  local path="${1:-packages}"

  metadata:check "${path}" || return 1
  cat "${path}/metadata.json" | jq --raw-output '.packages // [] | join(",")'
}

# metadata:files
#   Extract and return a comma-separated list of all package files generated from this package base from the package
#   base metadata file
#
# path: The path to the directory where the metadata.json file is saved. Defaults to "packages".
function metadata:files {
  local path="${1:-packages}"

  metadata:check "${path}" || return 1
  cat "${path}/metadata.json" | jq --raw-output '.files // [] | join(",")'
}
