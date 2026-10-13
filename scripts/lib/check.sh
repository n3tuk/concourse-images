#!/usr/bin/env bash
# vim:set ft=bash:

# Check to see if the variable name provided both exists and has a value associated with it, otherwise output an error
# and exit the script
function check:variables {
  local variable
  for variable in "${@}"; do
    check:variable "${variable}"
  done
}

# Check to see if the variable name provided both exists and has a value associated with it, otherwise output an error
# and exit the script
function check:variable {
  local variable=${1%%:*}
  local sensitive=false

  # Allow us to check for the presence of the variable, but not output the contents, when we know the information will
  # be sensitive (in most cases GitHub Actions should protect against this, but we should avoid doing it regardless,
  # where possible)
  if [[ ${1##*:} == "sensitive" ]]; then
    sensitive=true
  fi

  set +u # Don't error out on unbound variables in this part of the function
  if [[ -z ${!variable} ]]; then
    log:fatal "An environment variable is missing and is required" variable="${variable}"
  fi
  set -u # We know the variable is bound now, restore the check

  output:variable "${variable}" "${sensitive}"
}

# Check to see if all the commands provided exist and are executable (and as such are available via the $PATH variable),
# otherwise output an error and exit the script
function check:commands {
  local command
  for command in "${@}"; do
    check:command "${command}"
  done
}

# Check to see if the command provided both exists and is executable (and as such is available via the $PATH variable),
# otherwise error and exit the script
function check:command {
  local command="${1}"
  if [[ ! -x "$(command -v "${command}")" ]]; then
    log:fatal "An application is missing and is required" command="${command}"
  fi
}

# Deal with the different methods of reference the location of the Terraform configuration, including relative to the
# repository (path/to), relative to the root of the repository (./path/to), and absolute paths within the repository
# (/path/to). For each case, provide a clean version of the path which can be used for display purposes. There is no
# context in which the path should be output of the repository root, so we will always output the path relative to the
# repository root, even if the input was an absolute path.
function check:path {
  local path=${1:-.}

  if [[ ${path} == "." || ${path} == "/" || ${path} == "./" ]]; then
    echo "${GITHUB_WORKSPACE}"
  elif [[ ${path:0:2} == "./" ]]; then
    echo "${GITHUB_WORKSPACE}/${path:2}"
  elif [[ ${path:0:1} == "/" ]]; then
    echo "${GITHUB_WORKSPACE}/${path:1}"
  else
    echo "${GITHUB_WORKSPACE}/${path}"
  fi
}
