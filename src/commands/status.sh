# shellcheck shell=bash

command.status.update_table() {
  local manager=$1
  local remove=$2
  local headers
  headers=("${BLUE}${BOLD}Package${NO_COLOR}" "${BLUE}${BOLD}Local${NO_COLOR}" "${BLUE}${BOLD}Remote${NO_COLOR}")
  local levels=()
  local messages=()

  local i=1
  while IFS=, read -ra line; do
    local dependency=${line[0]}
    local local_version="${statuses[${dependency}_local_version]}"
    local remote_version="${statuses[${dependency}_remote_version]}"

    local is_installed=false
    local exists=false
    local is_uptodate=false
    local local_version_done=false
    local remote_version_done=false
    local both_version_done=false
    local local_version_text="..."
    local remote_version_text="..."
    local local_version_color=""
    local remote_version_color=""
    local level="info"

    [[ "$local_version"  != "$PACKAGE_NONE"   ]] && is_installed=true
    [[ "$remote_version" != "$PACKAGE_NONE"   ]] && exists=true
    [[ "$local_version"  == "$remote_version" ]] && is_uptodate=true

    helpers.is_set "$local_version"             && local_version_done=true
    helpers.is_set "$remote_version"            && remote_version_done=true
    $local_version_done && $remote_version_done && both_version_done=true

    $local_version_done  && local_version_text="$local_version"
    $remote_version_done && remote_version_text="$remote_version"

    $local_version_done  && ! $is_installed && local_version_color="$RED"  && level="error"
    $remote_version_done && ! $exists       && remote_version_color="$RED" && level="error"

    $both_version_done                                    && local_version_color="$RED"
    $both_version_done   && $is_installed                 && local_version_color="$YELLOW"
    $both_version_done   && $is_installed && $is_uptodate && local_version_color="$GREEN"
    $both_version_done                                    && level="error"
    $both_version_done   && $is_installed                 && level="warning"
    $both_version_done   && $is_installed && $is_uptodate && level="success"

    messages+=("${BOLD}$dependency${NO_COLOR}")
    messages+=("${local_version_color}$local_version_text${NO_COLOR}")
    messages+=("${remote_version_color}$remote_version_text${NO_COLOR}")
    levels+=("$level")
    i=$((i + 1))
  done < <(core.csv.get "$manager")

  local manager_version="${statuses[${manager}_version]}"
  local title

  if helpers.is_set "$manager_version"; then
    title="${BLUE}${BOLD}$manager${NO_COLOR} ($manager_version)"
  else
    title="${BLUE}${BOLD}$manager${NO_COLOR} (...)"
  fi

  # Clear screen
  for i in $(seq 1 "$remove"); do
    tput cuu1
  done

  table.print "$title" headers[@] levels[@] messages[@]
}

command.status.manager.version() {
  local manager=$1

  local version
  version=$(core.manager.version "$manager")

  until [ -p "$FIFO" ]; do sleep 0.1; done
  echo "${manager}_version,$version" >"$FIFO"
}

command.status.package.version() {
  local version_type=$1
  local dependency=$2

  local version
  version=$("core.package.${version_type}_version" "$manager" "$dependency" false)

  until [ -p "$FIFO" ]; do sleep 0.1; done
  echo "${dependency}_${version_type}_version,$version" > "$FIFO"
}

command.status() {
  local manager=$1
  declare -A statuses

  [ -p "$FIFO" ] && rm "$FIFO"

  command.status.manager.version "$manager" &

  local line_count=0
  while IFS=, read -ra line; do
    local dependency=${line[0]}

    command.status.package.version "local"  "$dependency" &
    command.status.package.version "remote" "$dependency" &

    line_count=$((line_count + 1))
  done < <(core.csv.get "$manager")

  local redraw=false
  [ -t 1 ] && redraw=true

  "$redraw" && command.status.update_table "$manager" 0
  mknod "$FIFO" p

  local j=0
  while true; do
    read -r data
    ! helpers.is_set "$data" && continue

    local array
    IFS=, read -r -a array <<< "$data"
    statuses["${array[0]}"]="${array[1]}"

    "$redraw" && command.status.update_table "$manager" $((line_count + 2))

    j=$((j + 1))
    (( j == $((line_count * 2 + 1)) )) && break
  done <"$FIFO"

  ! "$redraw" && command.status.update_table "$manager" 0
}

