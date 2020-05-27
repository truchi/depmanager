# shellcheck shell=bash

#
# Prints status table
# Redraw $2 lines
# Throttles 1 second
#
command.status.update_table() {
  # Throttle 1s
  [[ -z $last_update ]] && last_update=0
  local now
  now=$(date +%s)
  ((now - last_update < 1)) && return

  local manager=$1
  local remove=$2
  local headers=()
  local levels=()
  local messages=()

  # Make array for table
  local i=1
  while IFS=, read -ra line; do
    local package=${line[0]}

    # We try to read the cache for version
    local local_version_done=false
    local remote_version_done=false
    local both_versions_done=false

    cache.has "core_package_version_local__${manager}__${package}"  && local_version_done=true
    cache.has "core_package_version_remote__${manager}__${package}" && remote_version_done=true
    $local_version_done && $remote_version_done                     && both_versions_done=true

    # Read cache if set
    local local_version="..."
    local remote_version="..."
    $local_version_done  && local_version=$(core.package.version.local   "$manager" "$package")
    $remote_version_done && remote_version=$(core.package.version.remote "$manager" "$package")

    # Check the statuses of package
    local is_installed=false
    local exists=false
    local is_uptodate=false

    $local_version_done  && core.package.is_installed "$manager" "$package" && is_installed=true
    $remote_version_done && core.package.exists       "$manager" "$package" && exists=true
    $both_versions_done  && core.package.is_uptodate  "$manager" "$package" && is_uptodate=true

    # Prepare printing vars
    local local_version_color=""
    local remote_version_color=""
    local level="info"

    $local_version_done  && ! $is_installed && local_version_color="$RED"  && level="error"
    $remote_version_done && ! $exists       && remote_version_color="$RED" && level="error"

    $both_versions_done                                    && local_version_color="$RED"
    $both_versions_done   && $is_installed                 && local_version_color="$YELLOW"
    $both_versions_done   && $is_installed && $is_uptodate && local_version_color="$GREEN"
    $both_versions_done                                    && level="error"
    $both_versions_done   && $is_installed                 && level="warning"
    $both_versions_done   && $is_installed && $is_uptodate && level="success"

    # Table row
    messages+=("${BOLD}$package${NO_COLOR}")
    messages+=("${local_version_color}$local_version${NO_COLOR}")
    messages+=("${remote_version_color}$remote_version${NO_COLOR}")
    levels+=("$level")

    i=$((i + 1))
  done < <(core.csv.get "$manager")

  # Same, need cache
  local manager_version="..."
  cache.has "core_manager_version__$manager" && manager_version=$(core.manager.version "$manager")

  # Title and headers
  local title="${BLUE}${BOLD}$manager${NO_COLOR} ($manager_version)"
  headers+=("${BLUE}${BOLD}Package${NO_COLOR}")
  headers+=("${BLUE}${BOLD}Local${NO_COLOR}")
  headers+=("${BLUE}${BOLD}Remote${NO_COLOR}")

  # Clear screen
  # (status should never be quiet, screen should be drawn only once outside a terminal)
  if ! $QUIET && $IN_TERMINAL; then
    for i in $(seq 1 "$remove"); do
      tput cuu1
    done
  fi

  # Print!
  table.print "$title" headers[@] levels[@] messages[@]
  last_update=$(date +%s)
}

command.status() {
  local manager=$1
  local length
  length=$(core.csv.length "$manager")
  length=$((length + 2))

  # If in terminal
  if $IN_TERMINAL; then
    last_update=0
    command.status.update_table "$manager" 0
    core.manager.async.versions "$manager" "command.status.update_table" "$manager" "$length"
    last_update=0
    command.status.update_table "$manager" "$length"
  else
    core.manager.async.versions "$manager"
    command.status.update_table "$manager" 0
  fi
}

