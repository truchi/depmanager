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
    ! is_absolute "$dir" && dir="$HOME/$dir"
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
  local manager="$1"
  local file=""

  # If file is given in args
  if is_set "${ARG[$manager]}"; then
    # Use file arg
    file="${ARG[$manager]}"

    # Relative to current working dir
    ! is_absolute "$file" && ! is_url "$file" && file="$CWD/$file"
  else
    # Use default file, relative to ARG[dir]
    file="${ARG[dir]}/${DEFAULT[$manager]}"
  fi

  ARG[$manager]="$file"
}

#
# Sets `FOUND[$1]` to true if ${ARG[$1]} exists (file/url), to false otherwise
# Returns true in this case, false otherwise
#
check_file() {
  local manager="$1"
  local file="${ARG[$manager]}"

  # If already found, do not try to find again
  if is_set "${FOUND[$manager]}";then
    "${FOUND[$manager]}"
    return
  fi

  # Check for existence of file/url
  if (is_url "$file" && url_exists "$file") || file_exists "$file"; then
    FOUND[$manager]=true
    true
  else
    FOUND[$manager]=false
    false
  fi
}

#
# Sets `DETECT$[$1]` to true if the manager is found on the system, to false otherwise
# Returns true in this case, false otherwise
# Does not detect twice, reuses `DETECT$[$manager]`
#
detect_manager() {
  local manager="$1"

  # If already detected, do not try to detect again
  if is_set "${DETECT[$manager]}"; then
    "${DETECT[$manager]}"
    return
  fi

  # Detection
  if command_exists "${manager}_detect" && ${manager}_detect; then
    DETECT[$manager]=true
    true
  else
    DETECT[$manager]=false
    false
  fi
}

