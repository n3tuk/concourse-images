#!/usr/bin/env bash
# vim:set ft=bash:

# Show the value of each of the variables provided
function output:variables {
  for variable in "${@}"; do
    output:variable "${variable}"
  done
}

# Show the value of the variable
function output:variable {
  local variable="${1}" value="${!1-}" sensitive="${2:-false}"
  if [[ -z ${value} ]]; then
    log:debug variable="${variable}" empty="true" sensitive="${sensitive}"
  else
    if [[ ${sensitive} != "false" ]]; then
      log:debug variable="${variable}" empty="false" sensitive="${sensitive}"
    else
      log:debug variable="${variable}" empty="false" sensitive="${sensitive}" value="${value}"
    fi
  fi
}
