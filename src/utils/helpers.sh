# shellcheck shell=bash

#
# Returns true is $1 is set, false otherwise
#
helpers.is_set() {
  [[ -n "$1" ]]
}

#
# Returns true if file $1 exists, false otherwise
#
helpers.file_exists() {
  [[ -f "$1" ]]
}

#
# Returns true if url $1 exists, false otherwise
#
helpers.url_exists() {
  wget -q --spider "$1"
}

#
# Returns true if $1 is found on the system, false otherwise
#
helpers.command_exists() {
  command -v "$1" >/dev/null 2>&1
}

