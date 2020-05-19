# shellcheck shell=bash
# shellcheck source=../vars.sh
. ""

#
# Sets and returns $1 manager's CSV path according to (in this precedence order):
# - cli arg          (relative to current workin directory)
# - default variable (relative to `CSVS[dir]`, see core.dir.resolve)
#
core.csv.path() {
  local manager="$1"
  local file="${CSVS[$1]}"

  # If file is given in args
  if helpers.is_set "$file"; then
    if [[ "$file" != false ]]; then
      # Expand ~
      file="${file/#\~/$HOME}"

      # Relative to current working dir
      ! string.is_absolute "$file" && ! string.is_url "$file" && file="$(realpath -m "$file")"
    fi
  else
    # Use default file, relative to CSVS[dir]
    file="${CSVS[dir]}/${DEFAULTS[$manager]}"
  fi

  CSVS[$manager]="$file"
  echo "$file"
}

#
# Returns true if $1 manager's CSV exists (file/url), false otherwise
# With cache
#
core.csv.exists() {
  local manager="$1"
  local cache="$2"

  # Do not worry about "false" values
  if core.manager.is_bypassed "$manager"; then
    true
    return
  fi

  if string.is_empty "$cache"; then
    cache=true
  fi

  local file
  file=$(core.csv.path "$manager")

  local cmd
  if string.is_url "$file"; then cmd="helpers.url_exists $file"
  else                           cmd="helpers.file_exists $file"
  fi

  helpers.cache \
    "core_csv_exists__$file" \
    "$cache" \
    "$cache" \
    "$cmd"
}

#
# Returns content of $1 manager's CSV
# With cache
#
core.csv.get() {
  local manager="$1"
  local file
  file=$(core.csv.path "$manager")

  helpers.cache "core_csv_get__$file" true true "__core.csv.get" "$file"
}

__core.csv.get() {
  local file="$1"

  if string.is_url "$file"; then
    wget "$file" | helpers.sanitize_csv
  else
    helpers.sanitize_csv < "$file"
  fi
}

#
# Retuns true if $1 manager's CSV is empty, false otherwise
#
core.csv.is_empty() {
  local manager="$1"
  local i=0

  # Count non-empty lines
  while IFS=, read -ra line; do
    # TODO should account whitespaces as empty lines
    helpers.is_set "${line[0]}" && i=$((i + 1))
  done < <(core.csv.get "$manager")

  # Do we have non-empty lines?
  ! ((i > 0))
}

