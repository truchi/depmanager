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
      # Init cache for version
      core.manager.version "$SYSTEM_MANAGER" > /dev/null
      return
    fi
  done
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
core.manager.is_ignored() {
  [[ $(core.csv.path "$1") == "ignore" ]]
}

###############################################################
# Functions below cache corresponding functions in managers/  #
###############################################################

#
# Returns true if manager $1 is found on the system, false otherwise
# With cache (system managers only)
#
core.manager.exists() {
  local manager="$1"

  helpers.cache \
    "core_manager_exists__$manager" \
    true \
    "$(core.manager.is_system "$manager" && echo true || echo false)" \
    "managers.${manager}.exists"
}

#
# Returns manager $1 version
# With cache
#
core.manager.version() {
  local manager="$1"
  local write_cache="$2"

  if string.is_empty "$write_cache"; then
    write_cache=true
  fi

  helpers.cache \
    "core_manager_version__$manager" \
    true \
    "$write_cache" \
    "managers.${manager}.version"
}

