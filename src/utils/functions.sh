#!/bin/bash

#
# Sets `DIR` according to (in this precedence order):
# - env variable (relative to home)
# - default path
#
get_dir() {
  local dir=""

  # If env variable is defined
  if is_set "$DEPMANAGER_DIR"; then
    # Use user's dir
    dir="$DEPMANAGER_DIR"

    # Relative to home
    if ! is_absolute "$dir"; then
      dir="$HOME/$dir"
    fi
  else
    # Use default dir
    dir="${DEFAULT[dir]}"
  fi

  ARG[dir]="$dir"
}

#
# Sets `ARG[$1]` according to (in this precedence order):
# - cli arg          (relative to current workin directory)
# - default variable (relative to `DIR`)
# Assumes `CWD` is set
#
make_path() {
  local type="$1"
  local file=""

  # If file is given in args
  if is_set "${ARG[$type]}";then
    # Use file arg
    file="${ARG[$type]}"

    # Relative to current working dir
    if ! is_absolute "$file" && ! is_url "$file"; then
      file="$CWD/$file"
    fi
  else
    # Use default file, relative to ARG[dir]
    file="${ARG[dir]}/${DEFAULT[$type]}"
  fi

  ARG[$type]="$file"
}

#
# sets `FOUND[$1]` to true if ${ARG[$1]} exists (file/url)
#
check_file() {
  local type="$1"
  local file="${ARG[$type]}"

  if (is_url "$file" && url_exists "$file") || file_exists "$file"; then
    FOUND[$type]=true
  fi
}

#
# Sets `DETECT$[$1]` to true if the manager is found on the system,
# to false otherwise
#
detect_manager() {
  local type="$1"

  if command_exists "${type}_detect" && ${type}_detect; then
    DETECT[$type]=true
  else
    DETECT[$type]=false
  fi
}

