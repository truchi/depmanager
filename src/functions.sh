#!/bin/bash

#
# Returns true if $1 starts with /, false otherwise
#
is_absolute() {
  if [[ "$1" =~ / ]]; then return 0
  else return 1
  fi
}

#
# Returns true if $1 starts with https?://, false otherwise
#
is_url() {
  if [[ "$1" =~ https?:// ]]; then return 0
  else return 1
  fi
}

#
# Returns true is $1 is set, false otherwise
#
is_set() {
  if [[ ! -z "$1" ]]; then return 0
  else return 1
  fi
}

#
# Sets `ARG[DIR]` according to (in this precedence order):
# - cli arg      (relative to current working directory)
# - env variable (relative to home)
# - default path
# Assumes `CWD` is set
#
get_dir() {
  local dir=""

  # If dir is given in args
  if is_set "${ARG[DIR]}"; then
    # Use dir arg
    dir="${ARG[DIR]}"

    # Relative to current working dir
    if ! is_absolute "$dir"; then
      dir="$CWD/$dir"
    fi
  else
    # If env variable is defined
    if is_set "$DEPMANAGER_DIR"; then
      # Use user's dir
      dir=$DEPMANAGER_DIR

      # Relative to home
      if ! is_absolute "$dir"; then
        dir="$HOME/$dir"
      fi
    else
      # Use default dir
      dir=${DEFAULT[DIR]}
    fi
  fi

  ARG[DIR]=$dir
}

#
# Sets `ARG[$1]` according to (in this precedence order):
# - cli arg          (relative to current workin directory)
# - default variable (relative to `ARG[DIR]`)
# Assumes `CWD` is set
#
make_path() {
  local type=$1
  local file=""
  # local dir="${ARG[DIR]}"
  # local path="${ARG[$type]}"

  # If file is given in args
  if is_set "${ARG[$type]}";then
    # Use file arg
    file="${ARG[$type]}"

    # Relative to current working dir
    if ! is_absolute "$file" && ! is_url "$file"; then
      file="$CWD/$file"
    fi
  else
    # Use default file, relative to ARG[DIR]
    file="${ARG[DIR]}/${DEFAULT[$type]}"
  fi

  ARG[$type]=$file
}

#
# Checks the existence of file/url ${ARG[$1]}
# Sets it to false when not
#
check_file() {
  local type=$1
  local file="${ARG[$type]}"

  if is_url "$file"; then
    if ! wget -q --spider $file; then
      ARG[$type]=false
    fi
  elif [[ ! -f "$file" ]]; then
    ARG[$type]=false
  fi
}

get_deps() {
  local type=$1                    # SYSTEM or NODE or RUST
  local file="$DIR/${FILE[$type]}"

  echo type: $type
  echo file: $file

  if [[ -f $file ]]; then
    echo "It exitsts"
  else
    echo "It dont exitsts"
  fi
}

