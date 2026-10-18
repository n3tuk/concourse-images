#!/usr/bin/env bash
# vim:set ft=bash:

# srcinfo:field
#   Extract the first value for the given key from a .SRCINFO file, tolerating optional surrounding
#   whitespace around both the key and the '=' separator. Both the package builder and the metadata
#   generator read .SRCINFO, so they must agree on this parsing; keep all extraction routed here.
#
# file - The path to the .SRCINFO file to read.
# key  - The field name to extract (e.g. pkgbase, pkgver, pkgrel).
function srcinfo:field {
  local file="${1}" key="${2}"
  grep -E "^[[:space:]]*${key}[[:space:]]*=" "${file}" \
    | head -n 1 | cut -d= -f2- | tr -d '[:space:]'
}

function build:package {
  local resource="${1}" name
  name=$(srcinfo:field "${resource}/.SRCINFO" pkgbase)

  if test -z "${name}"; then
    log:fatal "Failed to extract package base name from .SRCINFO" resource="${resource}" file=".SRCINFO"
    return 1
  fi

  printf "%s" "${name}"
}

function build:version {
  local resource="${1}" version release
  version=$(srcinfo:field "${resource}/.SRCINFO" pkgver)
  release=$(srcinfo:field "${resource}/.SRCINFO" pkgrel)

  if test -z "${version}" || test -z "${release}"; then
    log:fatal "Failed to extract package version from .SRCINFO" resource="${resource}" file=".SRCINFO"
    return 1
  fi

  printf "%s-%s" "${version}" "${release}"
}

function build:makepkg {
  local resource="${1}"
  local package version

  package=$(build:package "${resource}")
  version=$(build:version "${resource}")

  log:info "Building Arch Linux Repository package" resource="${resource}" package="${package}" version="${version}"
  (cd "${resource}" && makepkg --nosign --syncdeps --noconfirm)
}

function build:save {
  local source="${1}" packages="${2}"

  log:info "Saving Arch Linux Repository packages" source="${source}" packages="${packages}"

  declare -a files
  mapfile -t files < <(find "${source}" -maxdepth 1 -type f -name "*.pkg.tar.zst")

  if [[ ${#files[@]} -eq 0 ]]; then
    log:warning "No packages found" source="${source}" extension=".pkg.tar.zst"
    return 0
  fi

  for file in "${files[@]}"; do
    if [[ ! -r ${file} ]]; then
      log:warning "Package found, but it does not exist or is not readable" source="${source}" file="${file}"
      continue
    fi

    local size
    size=$(stat -c %s "${file}")

    log:debug "Saving build artifact" source="${source}" packages="${packages}" file="${file}" size="${size}"

    cp "${file}" "${packages}"
  done

  # Make a copy of .SRCINFO into the resource directory so that it can be used to provide package metadata for the package
  # signing task, and to provide a record of the package metadata for any other tasks that may need to reference it.
  cp "${source}/.SRCINFO" "${packages}"
}

function build:import {
  local key="${1}" passphrase="${2}"
  local tmp

  log:info "Importing the GPG private key for signing"

  tmp=$(mktemp "${HOME}/.import.XXXXXXXX.key")
  # Remove the on-disk key material even if the import fails part-way through.
  trap 'shred -u "${tmp}" 2>/dev/null || rm -f "${tmp}"' RETURN

  printf '%s\n' "${key}" >"${tmp}"
  printf '%s\n' "${passphrase}" \
    | gpg --batch --passphrase-fd 0 --pinentry-mode loopback --yes --import "${tmp}"
}

function build:sign {
  local packages="${1}" id="${2}" passphrase="${3}"
  local package version

  declare -a files
  mapfile -t files < <(find "${packages}" -maxdepth 1 -type f -name "*.pkg.tar.zst")

  if [[ ${#files[@]} -eq 0 ]]; then
    log:warning "No packages found" packages="${packages}" extension=".pkg.tar.zst"
    return 0
  fi

  package=$(build:package "${packages}")
  version=$(build:version "${packages}")

  log:info "Signing Arch Linux Repository package" packages="${packages}" package="${package}" version="${version}" \
    id="${id}"

  for file in "${files[@]}"; do
    if [[ ! -r ${file} ]]; then
      log:warning "Package found, but it does not exist or is not readable" packages="${packages}" \
        package="${package}" version="${version}" file="${file}"
      continue
    fi

    log:debug "Signing build artifact" packages="${packages}" package="${package}" version="${version}" file="${file}" \
      id="${id}"

    echo "${passphrase}" \
      | gpg --local-user "${id}" --batch --passphrase-fd 0 --pinentry-mode loopback --yes \
        --output "${file}.sig" --detach-sign "${file}"
  done
}

function build:cleanup {
  local id="${1}" fingerprint="${2}"

  log:info "Removing the GPG private key for signing" id="${id}" fingerprint="${fingerprint}"

  if ! gpg --batch --yes --delete-secret-key "${fingerprint}"; then
    log:warning "Failed to remove the GPG private key" id="${id}" fingerprint="${fingerprint}"
  fi
}
