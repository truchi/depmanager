# shellcheck shell=bash
# shellcheck source=vars.sh
. ""

#
# Sets `DIR` according to (in this precedence order):
# - env variable (relative to home)
# - default path
#
core.dir.resolve() {
  local dir=""

  # If env variable is defined
  if helpers.is_set "$DEPMANAGER_DIR"; then
    # Use user's dir
    dir="$DEPMANAGER_DIR"

    # Relative to home
    ! string.is_absolute "$dir" && dir="$HOME/$dir"
  else
    # Use default dir
    dir="${DEFAULTS[dir]}"
  fi

  CSVS[dir]="$dir"
}

#
# Sets `CSVS[$1]` according to (in this precedence order):
# - cli arg          (relative to current workin directory)
# - default variable (relative to `DIR`)
#
core.csv.resolve() {
  local manager="$1"
  local file=""

  # If file is given in args
  if helpers.is_set "${CSVS[$manager]}"; then
    # Use file arg
    file="${CSVS[$manager]}"
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
# Returns true if ${CSVS[$1]} exists (file/url), false otherwise
# With cache
#
core.csv.exists() {
  local manager="$1"
  local read_cache="$2"
  local file="${CSVS[$manager]}"

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
# Returns true if the manager is found on the system, false otherwise
# With cache (system managers only)
#
core.manager.exists() {
  local manager="$1"

  # If already detected, do not try to detect again
  if helpers.is_set "${__cache_core_manager_exists[$manager]}"; then
    "${__cache_core_manager_exists[$manager]}"
    return
  fi

  # Detection
  if helpers.command_exists "${manager}_detect" && "${manager}_detect"; then
    core.manager.is_system "$manager" && __cache_core_manager_exists[$manager]=true
    true
  else
    core.manager.is_system "$manager" && __cache_core_manager_exists[$manager]=false
    false
  fi
}

#
# Sets `SYSTEM_MANAGER` to the first found system manager
#
core.manager.system() {
  # Already detected?
  helpers.is_set "$SYSTEM_MANAGER" && return

  # Try all system managers
  for manager in "${SYSTEM_MANAGERS[@]}"; do
    if core.manager.exists "$manager"; then
      SYSTEM_MANAGER="$manager"
      return
    fi
  done
}

#
# Returns content of file/url ${CSVS[$1]}
# With cache
#
core.csv.get() {
  local manager="$1"
  local file="${CSVS[$manager]}"

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

#
# Returns true if manager $1 is by-passed
#
core.manager.is_bypassed() {
  [[ "${CSVS[$1]}" == false ]]
}

#
# Returns CSV path for manager $1
#
core.csv.path() {
  echo "${CSVS[$1]}"
}

#
# Returns true if $1 is in `SYSTEM_MANAGERS`, false otherwise
#
core.manager.is_system() {
  array.includes "$1" SYSTEM_MANAGERS[@]
}

