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
  local manager="$1"
  local file=""

  # If file is given in args
  if is_set "${ARG[$manager]}"; then
    # Use file arg
    file="${ARG[$manager]}"

    # Relative to current working dir
    if ! is_absolute "$file" && ! is_url "$file"; then
      file="$CWD/$file"
    fi
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
  if is_set "${FOUND[$manager]}"; then
    if "${FOUND[$manager]}"; then
      return 0
    else 
      return 1
    fi
  fi

  # Check for existence of file/url
  if (is_url "$file" && url_exists "$file") || file_exists "$file"; then
    FOUND[$manager]=true
    return 0
  else
    FOUND[$manager]=false
    return 1
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
    if "${DETECT[$manager]}"; then
      return 0
    else 
      return 1
    fi
  fi

  # Detection
  if command_exists "${manager}_detect" && ${manager}_detect; then
    DETECT[$manager]=true
    return 0
  else
    DETECT[$manager]=false
    return 1
  fi
}

