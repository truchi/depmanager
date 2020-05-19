# shellcheck shell=bash

command.status.update_table() {
  local manager=$1
  local remove=$2
  local headers
  headers=("${BLUE}${BOLD}Package${NO_COLOR}" "${BLUE}${BOLD}Local${NO_COLOR}" "${BLUE}${BOLD}Remote${NO_COLOR}")
  local levels=()
  local messages=()

  ((remove > 0)) && echo -e "$(tput cuu "$remove")"

  local i=1
  while IFS=, read -ra line; do
    local dependency=${line[0]}
    ! helpers.is_set "$dependency" && continue

    local local_version="${statuses[${dependency}_local_version]}"
    local remote_version="${statuses[${dependency}_remote_version]}"
    local local_version_done
    local remote_version_done
    local_version_done=$(helpers.is_set "$local_version" && echo true || echo false)
    remote_version_done=$(helpers.is_set "$remote_version" && echo true || echo false)

    messages+=("${BOLD}$dependency${NO_COLOR}")
    $local_version_done  && messages+=("$local_version")  || messages+=("...")
    $remote_version_done && messages+=("$remote_version") || messages+=("...")

    if $local_version_done && $remote_version_done; then
      local installed=false
      local up_to_date=false
      [[ "$local_version" != "NONE"            ]] && installed=true
      [[ "$local_version" == "$remote_version" ]] && up_to_date=true

      if   ! $installed; then levels+=("error")
      elif $up_to_date ; then levels+=("success")
      else                    levels+=("warning")
      fi
    else
      levels+=("info")
    fi

    i=$((i + 1))
  done < <(core.csv.get "$manager")

  local manager_version="${statuses[${manager}_version]}"
  local title

  if helpers.is_set "$manager_version"; then
    title="${BLUE}${BOLD}$manager${NO_COLOR} ($manager_version)"
  else
    title="${BLUE}${BOLD}$manager${NO_COLOR} (...)"
  fi

  table.print "$title" headers[@] levels[@] messages[@]
}

command.status.manager.version() {
  local manager=$1

  local version
  version=$(core.manager.version "$manager")

  until [ -p "$FIFO" ]; do sleep 0.1; done
  echo "${manager}_version,$version" >"$FIFO"
}

command.status.package.local_version() {
  local dependency=$1

  local version="NONE"
  if core.package.is_installed "$manager" "$dependency" false; then
    version=$(core.package.local_version "$manager" "$dependency" false)
  fi

  until [ -p "$FIFO" ]; do sleep 0.1; done
  echo "${dependency}_local_version,$version" >"$FIFO"
}

command.status.package.remote_version() {
  local dependency=$1

  local version
  version=$(core.package.remote_version "$manager" "$dependency" false)
  ! helpers.is_set "$version" && version="NONE"

  until [ -p "$FIFO" ]; do sleep 0.1; done
  echo "${dependency}_remote_version,$version" >"$FIFO"
}

command.status() {
  local manager=$1
  declare -A statuses

  [ -p "$FIFO" ] && rm "$FIFO"

  command.status.manager.version "$manager" &

  local i=0
  while IFS=, read -ra line; do
    local dependency=${line[0]}
    helpers.is_set "$dependency" || continue

    command.status.package.local_version  "$dependency" &
    command.status.package.remote_version "$dependency" &

    i=$((i + 1))
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
    "$redraw" && command.status.update_table "$manager" $((i + 3))

    j=$((j + 1))
    (( j == $((i * 2 + 1)) )) && break
  done <"$FIFO"

  ! "$redraw" && command.status.update_table "$manager" 0
}

