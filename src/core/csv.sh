# shellcheck shell=bash
# shellcheck source=../vars.sh
. ""

#
# Returns CSV path for manager $1
#
core.csv.path() {
  echo "${CSVS[$1]}"
}

#
# Sets $1 manager's CSV according to (in this precedence order):
# - cli arg          (relative to current workin directory)
# - default variable (relative to `CSVS[dir]`, see core.dir.resolve)
#
core.csv.resolve() {
  local manager="$1"
  local file
  file=$(core.csv.path "$manager")

  # If file is given in args
  if helpers.is_set "$file"; then
    # Expand ~
    file="${file/#\~/$HOME}"

    # Relative to current working dir
    ! string.is_absolute "$file" && ! string.is_url "$file" && file="$(realpath -m "$file")"
  else
    # Use default file, relative to CSVS[dir]
    file="${CSVS[dir]}/${DEFAULTS[$manager]}"
  fi

  CSVS[$manager]="$file"
}

#
# Returns true if $1 manager's CSV exists (file/url), false otherwise
# With cache
#
core.csv.exists() {
  local manager="$1"
  local read_cache="$2"
  local file
  file=$(core.csv.path "$manager")

  # If already found, do not try to find again
  if $read_cache && helpers.is_set "${__cache_core_csv_exists[$manager]}";then
    "${__cache_core_csv_exists[$manager]}"
    return
  fi

  # Check for existence of file/url
  if (string.is_url "$file" && helpers.url_exists "$file") || helpers.file_exists "$file"; then
    __cache_core_csv_exists[$manager]=true
    true
  else
    __cache_core_csv_exists[$manager]=false
    false
  fi
}

#
# Returns content of $1 manager's CSV
# With cache
#
core.csv.get() {
  local manager="$1"
  local file
  file=$(core.csv.path "$manager")

  # If already read, return from cache
  if helpers.is_set "${__cache_core_csv_get[$manager]}";then
    echo "${__cache_core_csv_get[$manager]}"
    return
  fi

  # Read file/url
  local csv
  if string.is_url "$file"; then
    csv=$(wget "$file")
  else
    csv=$(cat "$file")
  fi

  __cache_core_csv_get[$manager]="$csv"
  echo "$csv"
}

#
# Retuns true if $1 manager's CSV is empty, false otherwise
#
core.csv.is_empty() {
  local manager="$1"
  local i=0

  # Count non-empty lines
  while IFS=, read -ra line; do
    helpers.is_set "${line[0]}" && i=$((i + 1))
  done < <(core.csv.get "$manager")

  # Do we have non-empty lines?
  ! ((i > 0))
}

