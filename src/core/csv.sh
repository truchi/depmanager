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
    if [[ "$file" != "ignore" ]]; then
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

  # Do not worry about ignored
  if core.manager.is_ignored "$manager"; then
    true # NOTE or false?
    return
  fi

  local file
  file=$(core.csv.path "$manager")

  local cmd
  string.is_url "$file" && cmd="helpers.url_exists $file" || cmd="helpers.file_exists $file"

  string.is_empty "$cache" && cache=true
  cache "core_csv_exists__$file" "$cache" "$cache" "$cmd"
}

#
# Returns content of $1 manager's CSV
# With cache
#
core.csv.get() {
  local manager="$1"
  local file
  file=$(core.csv.path "$manager")

  cache "core_csv_get__$file" true true "__core.csv.get" "$file"
}

#
# Returns content of $1 manager's CSV
# For cache
#
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
core.csv.length() {
  local manager="$1"

  if core.csv.is_empty "$manager"; then
    echo 0
    return
  fi

  local csv
  csv=$(core.csv.get "$manager")

  wc -l <<< "$csv"
}

#
# Retuns true if $1 manager's CSV is empty, false otherwise
#
core.csv.is_empty() {
  local manager="$1"

  core.csv.get "$manager" > /dev/null
  string.is_empty "$(core.csv.get "$manager")"
}

