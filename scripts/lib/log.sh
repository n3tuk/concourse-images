#!/usr/bin/env bash
# vim:set ft=bash:

blue=""
green=""
yellow=""
red=""
white=""
reset=""

case "${NO_COLOR:-}" in
  1 | true | TRUE | yes | YES | on | ON) ;;
  *)
    blue="\e[34m"
    green="\e[32m"
    yellow="\e[33m"
    red="\e[31m"
    white="\e[1;37m"
    reset="\e[0m"
    ;;
esac

function log:fmt() {
  local level="${1:-crit}" msgid msg
  shift || true

  if [[ -z ${level} ]]; then
    log:fatal "Missing required log level"
  fi

  declare -a arguments=("--sd-param" "level=\"${level}\"")
  declare -a parameters=()

  local level_color="${reset}"
  local key_color="${blue}"
  local msg_color="${white}"
  case "${level}" in
    debug)
      key_color="${reset}"
      msg_color="${reset}"
      ;;
    info) level_color="${white}" ;;
    warning) level_color="${yellow}" ;;
    err | crit) level_color="${red}" ;;
  esac

  printf "${blue}time${reset}=${green}%s${reset} ${blue}level${reset}=${level_color}%s${reset}" \
    "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")" "${level}" >&2

  for parameter in "${@}"; do
    test -z "${parameter}" && continue

    if [[ ${parameter} != *=* ]]; then
      msg="${parameter}"
      continue
    fi

    local key="${parameter%%=*}"
    local value="${parameter#*=}"

    arguments+=("--sd-param" "${key}=\"${value}\"")

    if [[ ${value} =~ [[:space:]] ]]; then
      parameters+=("${key_color}${key}${reset}=\"${msg_color}${value}${reset}\"")
    else
      parameters+=("${key_color}${key}${reset}=${msg_color}${value}${reset}")
    fi
  done

  if [[ -n ${msg:-} ]]; then
    if [[ ${msg} =~ [[:space:]] ]]; then
      printf " ${key_color}msg${reset}=\"${msg_color}%s${reset}\"" "${msg}" >&2
    else
      printf " ${key_color}msg${reset}=${msg_color}%s${reset}" "${msg}" >&2
    fi
  fi

  printf ' %b' "${parameters[@]}" >&2
  echo >&2

  msgid=$(uuidgen --time-v7)
  # Structured logging to the journal/syslog is best-effort: a logger failure must never abort the
  # resource step, which still needs to emit its JSON document on stdout.
  logger --id=$$ \
    --tag "${0}" --msgid "${msgid}" \
    --priority "user.${level}" \
    --rfc5424=notq --sd-id logType@1 "${arguments[@]}" "${msg:-}" || true
}

function log:success() {
  local msg="${1}"
  shift
  log:fmt "info" "${msg}" type="success" "${@}"
}

function log:failure() {
  local msg="${1}"
  shift
  log:fmt "warning" "${msg}" type="failure" "${@}"
}

function log:info() {
  local msg="${1}"
  shift
  log:fmt "info" "${msg}" "${@}"
}

function log:warning() {
  local msg="${1}"
  shift
  log:fmt "warning" "${msg}" "${@}"
}

function log:error() {
  local msg="${1}"
  shift
  log:fmt "err" "${msg}" "${@}"
}

function log:debug() {
  local msg="${1}"
  shift
  log:fmt "debug" "${msg}" "${@}"
}

function log:fatal() {
  local msg="${1}"
  shift
  log:fmt "crit" "${msg}" type="fatal" "${@}" exit="true"
  exit 1
}
