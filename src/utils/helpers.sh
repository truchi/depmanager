#!/bin/bash

#
# Returns true if $1 starts with /, false otherwise
#
is_absolute() {
  if [[ "$1" =~ / ]]; then
    return 0
  else
    return 1
  fi
}

#
# Returns true if $1 starts with https?://, false otherwise
#
is_url() {
  if [[ "$1" =~ https?:// ]]; then
    return 0
  else
    return 1
  fi
}

#
# Returns true is $1 is set, false otherwise
#
is_set() {
  if [[ ! -z "$1" ]]; then
    return 0
  else
    return 1
  fi
}

#
# Returns true if file $1 exists, false otherwise
#
file_exists() {
  if [[ -f "$1" ]]; then
    return 0
  else
    return 1
  fi
}

#
# Returns true if url $1 exists, false otherwise
#
url_exists() {
  if wget -q --spider "$1"; then
    return 0
  else
    return 1
  fi
}

#
# Returns true if $1 is found on the system, false otherwise
#
command_exists() {
  if command -v "$1" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}
