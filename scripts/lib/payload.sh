#!/usr/bin/env bash
# vim:set ft=bash:

set +e # We need to be able to handle the timeout command failing
payload=$(timeout 3s cat <&0)
if test -z "${payload}"; then
  log:fatal "Missing payload from stdin"
fi
set -e

# payload:lookup
#   Looks up a value from the JSON object passed as the resource payload to the STDIN of this script's execution. If the
#   value is required and not found, it will log a fatal error and exit.
#
# type      - The type of value to look up (should only be one of source, params, or version).
# key       - The key to look up within the specified payload type.
# required  - Whether the value is required (true) or optional (false). Defaults to true.
# default   - The default value to return if the key is not found. Defaults to an empty string.
# sensitive - Whether the value is sensitive (true) or not (false). Defaults to false. If true, the value will not be
#             logged in debug output.
function payload:lookup {
  local type="${1}" key="${2}" required="${3:-true}" default="${4:-}" sensitive="${5:-false}"
  value=$(jq --raw-output ".${type}.${key} // \"${default}\"" <<<"${payload}")

  if [[ ${required} == "true" && -z ${value} ]]; then
    log:fatal "Missing required ${type} value" type="${type}" key="${key}" exists="false"
  fi

  echo "${value}"
}

# payload:source
#   Looks up a value from the source section of the resource payload.
#
# key       - The key to look up within the source section of the payload.
# required  - Whether the value is required (true) or optional (false). Defaults to true.
# default   - The default value to return if the key is not found. Defaults to an empty string.
# sensitive - Whether the value is sensitive (true) or not (false). Defaults to false. If true, the value will not be
#             logged in debug output.
function payload:source {
  local key="${1}" required="${2:-true}" default="${3:-}" sensitive="${4:-false}"
  payload:lookup source "${key}" "${required}" "${default}" "${sensitive}"
}

# payload:params
#   Looks up a value from the params section of the resource payload.
#
# key       - The key to look up within the params section of the payload.
# required  - Whether the value is required (true) or optional (false). Defaults to true.
# default   - The default value to return if the key is not found. Defaults to an empty string.
# sensitive - Whether the value is sensitive (true) or not (false). Defaults to false. If true, the value will not be
#             logged in debug output.
function payload:params {
  local key="${1}" required="${2:-true}" default="${3:-}" sensitive="${4:-false}"
  payload:lookup params "${key}" "${required}" "${default}" "${sensitive}"
}

# payload:version
#   Looks up a value from the version section of the resource payload.
#
# key       - The key to look up within the version section of the payload.
# required  - Whether the value is required (true) or optional (false). Defaults to true.
# default   - The default value to return if the key is not found. Defaults to an empty string.
# sensitive - Whether the value is sensitive (true) or not (false). Defaults to false. If true, the value will not be
#             logged in debug output.
function payload:version {
  local key="${1}" required="${2:-true}" default="${3:-}" sensitive="${4:-false}"
  payload:lookup version "${key}" "${required}" "${default}" "${sensitive}"
}
