#!/bin/bash

#
# Sets `DIR` according to (in this precedence order):
# - env variable (relative to home)
# - default path
#
resolve_dir() {
  local dir=""

  # If env variable is defined
  if is_set "$DEPMANAGER_DIR"; then
    # Use user's dir
    dir="$DEPMANAGER_DIR"

    # Relative to home
    ! is_absolute "$dir" && dir="$HOME/$dir"
  else
    # Use default dir
    dir="${DEFAULTS[dir]}"
  fi

  PATHS[dir]="$dir"
}

#
# Sets `PATHS[$1]` according to (in this precedence order):
# - cli arg          (relative to current workin directory)
# - default variable (relative to `DIR`)
#
resolve_path() {
  local manager="$1"
  local file=""

  # If file is given in args
  if is_set "${PATHS[$manager]}"; then
    # Use file arg
    file="${PATHS[$manager]}"

    # Relative to current working dir
    ! is_absolute "$file" && ! is_url "$file" && file="$(pwd)/$file"
  else
    # Use default file, relative to PATHS[dir]
    file="${PATHS[dir]}/${DEFAULTS[$manager]}"
  fi

  PATHS[$manager]="$file"
}

#
# Returns true if ${PATHS[$1]} exists (file/url), false otherwise
# With cache
#
detect_path() {
  local manager="$1"
  local file="${PATHS[$manager]}"

  # If already found, do not try to find again
  if is_set "${__cache_detect_path[$manager]}";then
    "${__cache_detect_path[$manager]}"
    return
  fi

  # Check for existence of file/url
  if (is_url "$file" && url_exists "$file") || file_exists "$file"; then
    __cache_detect_path[$manager]=true
    true
  else
    __cache_detect_path[$manager]=false
    false
  fi
}

#
# Returns true if the manager is found on the system, false otherwise
# With cache (system managers only)
#
detect_manager() {
  local manager="$1"

  # If already detected, do not try to detect again
  if is_set "${__cache_detect_manager[$manager]}"; then
    "${__cache_detect_manager[$manager]}"
    return
  fi

  # Detection
  if command_exists "${manager}_detect" && ${manager}_detect; then
    is_system_manager $manager && __cache_detect_manager[$manager]=true
    true
  else
    is_system_manager $manager && __cache_detect_manager[$manager]=false
    false
  fi
}

#
# Sets `SYSTEM_MANAGER` to the first system manager detected
#
detect_system() {
  is_set $SYSTEM && return

  for manager in "${SYSTEM_MANAGERS[@]}"; do
    if detect_manager $manager; then
      SYSTEM_MANAGER="$manager"
      return
    fi
  done
}

#
# Returns true if `${PATHS[$1]}` equals false
#
is_bypassed() {
  [[ "${PATHS[$1]}" == false ]]
}

#
# Echos `${PATHS[$1]}`
#
get_path() {
  echo "${PATHS[$1]}"
}

# matrix_get_column() {
  # local n_lines=$1
  # local n_cols=$2
  # local matrix=$@
# }
