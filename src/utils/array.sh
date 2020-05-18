# shellcheck shell=bash

#
# Returns length of array $1
#
array.length() {
  local array=("${!1}")
  echo "${#array[*]}"
}

#
# Returns true if $1 is found in $2, false otherwise
#
array.includes() {
  local needle="$1"
  local array=("${!2}")

  for item in "${array[@]}"; do
    if [[ "$item" == "$needle" ]]; then
      true
      return
    fi
  done

  false
}
