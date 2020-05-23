# shellcheck shell=bash
# shellcheck source=../vars.sh
. ""

#
# Caches the return code and echoed string of a function
# DO NOT call from subshell: memory would not be written, script will die
#
cache() {
  local args=("$@")
  local cache_key="$1"
  local read_cache="$2"
  local write_cache="$3"
  local cmd="$4"

  local string
  local code

  # Read from cache or execute
  if $read_cache && cache.has "$cache_key"; then
    string=$(cache.get_string "$cache_key")
    code=$(cache.get_code "$cache_key")
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

      cache.set "$cache_key" "$string" "$code"
    fi
  fi

  # Echo string and return code
  string.is_empty "$string" || echo "$string"
  return $code
}

#
# Returns true if cache has data for in key $1, false otherwise
#
cache.has() {
  helpers.is_set "${__cache[$1]}"
}

#
# Gets cached string for key $1
#
cache.get_string() {
  echo "${__cache[__${1}__string]}"
}

#
# Gets cached code for key $1
#
cache.get_code() {
  echo "${__cache[__${1}__code]}"
}

#
# Sets cache string $2 and code $3 in key $1
#
cache.set() {
  __cache[$1]=true
  __cache[__${1}__string]="$2"
  __cache[__${1}__code]="$3"
}
