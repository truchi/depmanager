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
  local write_cache=false

  core.manager.is_system "$manager" && write_cache=true
  cache "core_manager_exists__$manager" true "$write_cache" "managers.${manager}.exists"
}

#
# Returns manager $1 version
# With cache
#
core.manager.version() {
  local manager="$1"
  local write_cache="$2"

  string.is_empty "$write_cache" && write_cache=true
  cache "core_manager_version__$manager" true "$write_cache" "managers.${manager}.version"
}

#
# Asynchronously writes the manager $1 version and packages versions (local/remote) in cache
# Runs command $2 as callback for async version calls, with $... args
#
core.manager.async.versions() {
  local manager="$1"
  local cmd="$2"
  local args=("$@")
  args=("${args[@]:2}")

  local fifo="$DEPMANAGER_TMP_DIR/fifo__${manager}"

  # Init async cache
  cache.async.init "$fifo"

  # Get manager version asynchronously
  (cache.async.write "$fifo" "core_manager_version__$manager" "$(core.manager.version "$manager" false)") &

  # Write CSV cache
  core.csv.get "$manager" > /dev/null

  # For all manager's packages
  local i=0
  while IFS=, read -ra line; do
    local package=${line[0]}

    # Asynchronously write versions in async cache
    (cache.async.write "$fifo" \
        "core_package_version_local__${manager}__${package}" \
        "$(core.package.version.local "$manager" "$package" false)") &
    (cache.async.write "$fifo" \
        "core_package_version_remote__${manager}__${package}" \
        "$(core.package.version.remote "$manager" "$package" false)") &

    i=$((i + 1))
  done < <(core.csv.get "$manager")

  # Listen to async cache fifo
  cache.async.listen "$fifo" $((i * 2 + 1)) "$cmd" "${args[@]}"
}

core.manager.install_or_update() {
  local manager="$1"

  print.info "${BOLD}${BLUE}$manager${NO_COLOR} (...)"

  local manager_version
  core.manager.version "$manager" > /dev/null
  manager_version=$(core.manager.version "$manager")

  $QUIET || print.clear.line
  print.info "${BOLD}${BLUE}$manager${NO_COLOR} ($manager_version)"

  IFS='
'
  for line in $(core.csv.get "$manager"); do
    local array
    IFS=',' read -ra array <<< "$line"
    IFS=' '

    local package="${array[0]}"

    print.info "${BOLD}$package${NO_COLOR} ..."

    local exists=false
    core.package.exists "$manager" "$package" && exists=true

    if ! $exists; then
      $QUIET || print.clear.line
      print.error "${BOLD}$package${NO_COLOR} does not exists"
      continue
    fi

    local local_version
    local remote_version
    local is_installed=false
    local is_uptodate=false

    core.package.version.local "$manager" "$package" > /dev/null
    local_version=$(core.package.version.local "$manager" "$package")
    remote_version=$(core.package.version.remote "$manager" "$package")
    core.package.is_installed "$manager" "$package" && is_installed=true
    core.package.is_uptodate  "$manager" "$package" && is_uptodate=true

    $QUIET || print.clear.line

    if $is_installed; then
      if $is_uptodate; then
        print.success "${BOLD}$package${NO_COLOR} is up-to-date (${BOLD}$local_version${NO_COLOR})"
      else
        print.warning "${BOLD}$package${NO_COLOR} is not up-to-date (local: ${BOLD}$local_version${NO_COLOR}, remote: ${BOLD}$remote_version${NO_COLOR})"
        core.package.install "$manager" "$package" "$QUIET"
      fi
    else
      local msg="${BOLD}$package${NO_COLOR} is not installed (remote: ${BOLD}$remote_version${NO_COLOR})"
      if [[ $COMMAND == "install" ]]; then
        print.warning "$msg"
        core.package.install "$manager" "$package"
      else
        print.warning "$msg, run ${BOLD}${YELLOW}install${NO_COLOR} to install"
      fi
    fi
  done
}
