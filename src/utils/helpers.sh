# shellcheck shell=bash
# shellcheck source=../vars.sh
. ""

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

#
# Returns true is executed in a subshell, false otherwise
#
helpers.is_subshell() {
  [ "$$" -ne "$BASHPID" ]
}

#
# Caches the return code and echoed string of a function
# DO NOT call from subshell: memory would not be written, script will die
#
helpers.cache() {
  local args=("$@")
  local cache_key="$1"
  local read_cache="$2"
  local write_cache="$3"
  local cmd="$4"

  local cache_string_key="__${cache_key}__string"
  local cache_code_key="__${cache_key}__code"
  local string
  local code

  # Read from cache or execute
  if $read_cache && helpers.is_set "${__cache[$cache_key]}"; then
    string="${__cache[$cache_string_key]}"
    code=${__cache[$cache_code_key]}
  else
    args=("${args[@]:4}")

    string=$($cmd "${args[@]}")
    code="$?"

    # Write to cache
    if $write_cache; then
      # NOTE cannot write cache in a subshell
      if helpers.is_subshell; then
        # Terminating whole script
        echo "HELPERS.CACHE CANNOT WRITE IN A SUBSHELL (key: $cache_key, cmd: $cmd)"
        kill $$
        exit
      fi

      __cache[$cache_key]="true"
      __cache[$cache_string_key]="$string"
      __cache[$cache_code_key]=$code
    fi
  fi

  # Echo string and return code
  ! string.is_empty "$string" && echo "$string"
  return $code
}
