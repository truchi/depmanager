#!/bin/bash

#
# Returns true if $1 starts with /, false otherwise
#
is_absolute() {
  [[ "$1" =~ / ]]
}

#
# Returns true if $1 starts with https?://, false otherwise
#
is_url() {
  [[ "$1" =~ https?:// ]]
}

#
# Returns true is $1 is set, false otherwise
#
is_set() {
  [[ ! -z "$1" ]]
}

#
# Returns true if file $1 exists, false otherwise
#
file_exists() {
  [[ -f "$1" ]]
}

#
# Returns true if url $1 exists, false otherwise
#
url_exists() {
  wget -q --spider "$1"
}

#
# Returns true if $1 is found on the system, false otherwise
#
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

#
# Returns true if $1 is in `SYSTEM_MANAGERS`, false otherwise
#
is_system_manager() {
  [[ " ${SYSTEM_MANAGERS[@]} " =~ " $1 " ]]
}

#
# Echos true if $1 is 0, false otherwise
#
code_to_boolean() {
  [[ $1 == 0 ]] && echo true || echo false
}

matrix_get_row() {
  local arr=$@
  local row=$1
  local n_rows=$2
  local n_cols=$3
  local first=$(($row * $n_cols))
  local last=$((($row + 1) * $n_cols - 1))
  local cells=""

  local i=-4
  for cell in ${arr[@]}; do
    i=$(($i + 1))
    (( $i < $first )) && continue
    (( $i > $last  )) && break
    cells="$cells $cell"
  done

  echo $cells
}

matrix_get_column() {
  local arr=$@
  local column=$1
  local n_cols=$3
  local cells=""

  local i=-4
  for cell in ${arr[@]}; do
    i=$(($i + 1))
    (( $i < 0)) && continue

    local n=$(($i % $n_cols))
    (( $n != $column )) && continue
    cells="$cells $cell"
  done

  echo $cells
}
