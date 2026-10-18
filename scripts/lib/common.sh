#!/usr/bin/env bash
# vim:set ft=bash:

LIB_DIR=${LIB_DIR:-../lib}

# shellcheck source=../lib/check.sh
source "${LIB_DIR}/check.sh"
# shellcheck source=../lib/log.sh
source "${LIB_DIR}/log.sh"
# shellcheck source=../lib/output.sh
source "${LIB_DIR}/output.sh"

# join_by
#   Joins the arguments with the first argument as the delimiter. For example, `join_by , a b c` will return `a,b,c`.
#
# delimiter - The delimiter to use for joining the arguments.
# elements  - The elements to join with the delimiter.
function join_by {
  local delimiter=${1-} elements=${2-}
  if shift 2; then
    printf %s "$elements" "${@/#/$delimiter}"
  fi
}
