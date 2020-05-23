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

#
# Returns true if manager $1 is found on the system, false otherwise
# With cache (system managers only)
#
core.manager.exists() {
  local manager="$1"

  cache \
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

  cache \
    "core_manager_version__$manager" \
    true \
    "$write_cache" \
    "managers.${manager}.version"
}

#
# Asynchronously writes the version of manager $2 in cache
# Async cache MUST listen fifo to $1
#
core.manager.async.version() {
  local fifo="$1"
  local manager="$2"

  local key="core_manager_version__$manager"
  local version
  version=$(core.manager.version "$manager" false)

  cache.async.write "$fifo" "$key" "$version"
}

#
# Asynchronously writes the manager $2 version and packages versions (local/remote) in cache
#
core.manager.async.versions() {
  local manager="$1"
  local fifo="$DEPMANAGER_CACHE_DIR/fifo__${manager}"

  # Creates new fifo
  [ -p "$fifo" ] && rm "$fifo"
  mknod "$fifo" p

  # Get manager version asynchronously
  core.manager.async.version "$fifo" "$manager" &

  # Writes CSV cache
  core.csv.get "$manager" > /dev/null

  # For all manager's packages
  local i=0
  while IFS=, read -ra line; do
    local package=${line[0]}
    # Get package versions asynchronously
    core.package.async.version.local  "$fifo" "$manager" "$package" &
    core.package.async.version.remote "$fifo" "$manager" "$package" &
    i=$((i + 1))
  done < <(core.csv.get "$manager")

  # Listen to fifo
  cache.async.listen "$fifo" $((i * 2 + 1))
}

