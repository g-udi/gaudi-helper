#!/usr/bin/env bash
# shellcheck shell=bash
#
# The old, misspelt name of bash-preexec.sh. Profiles written by earlier
# installers source this file by name, so it stays and loads the real one.
# shellcheck source=/dev/null
[[ -n "${__bp_imported:-}" ]] || source "${BASH_SOURCE[0]%/*}/bash-preexec.sh"
