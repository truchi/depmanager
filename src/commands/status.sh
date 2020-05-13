#!/bin/bash

declare -A statuses

update_status() {
  local dependency=$1
  local key=$2
  local version=$3

  statuses[${dependency}_${key}]=$version
}

run_status() {
  local manager=$1
  local file=$(get_path $manager)
  local title="${BLUE}${BOLD}$manager${NO_COLOR}"
  local headers=("${BLUE}${BOLD}Package${NO_COLOR}" "${BLUE}${BOLD}Local${NO_COLOR}" "${BLUE}${BOLD}Remote${NO_COLOR}")
  local levels=()
  local messages=()

  local i=1
  while IFS=, read -a line; do
    local dependency=${line[0]}
    ! is_set $dependency && continue

    local installed=false
    local local_version="NONE"
    local remote_version=$(${manager}_get_remote_version $dependency)
    local up_to_date

    ! is_set $remote_version && remote_version="NONE"

    if ${manager}_is_installed $dependency; then
      installed=true
      local_version=$(${manager}_get_local_version $dependency)
      up_to_date=$([[ "$local_version" == "$remote_version" ]] && echo true || echo false)
    fi

    if   ! $installed; then levels+=("error")
    elif $up_to_date ; then levels+=("success")
    else                    levels+=("warning")
    fi

    messages+=("${BOLD}$dependency${NO_COLOR}")
    messages+=("$local_version")
    messages+=("$remote_version")
    i=$(($i + 1))
  done < <(read_csv $manager)

  table_print "$title ($(${manager}_version))" headers[@] levels[@] messages[@]
}
