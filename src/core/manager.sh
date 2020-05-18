# shellcheck shell=bash
# shellcheck source=../vars.sh
. ""

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
# Returns true if $1 is in `SYSTEM_MANAGERS`, false otherwise
#
core.manager.is_system() {
  array.includes "$1" SYSTEM_MANAGERS[@]
}

#
# Returns true if manager $1 is by-passed
#
core.manager.is_bypassed() {
  [[ "${CSVS[$1]}" == false ]]
}

