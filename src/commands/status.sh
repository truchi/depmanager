#!/bin/bash

fifo="$DEPMANAGER_CACHE_DIR/fifo"
declare -A statuses

status_update_table() {
  local manager=$1
  local remove=$2
  local headers=("${BLUE}${BOLD}Package${NO_COLOR}" "${BLUE}${BOLD}Local${NO_COLOR}" "${BLUE}${BOLD}Remote${NO_COLOR}")
  local levels=()
  local messages=()

  echo -e $(tput cuu $remove)

  local i=1
  while IFS=, read -a line; do
    local dependency=${line[0]}
    ! is_set $dependency && continue

    local local_version="${statuses[${dependency}_local_version]}"
    local remote_version="${statuses[${dependency}_remote_version]}"
    local local_version_done=$(is_set $local_version && echo true || echo false)
    local remote_version_done=$(is_set $remote_version && echo true || echo false)

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

    i=$(($i + 1))
  done < <(read_csv $manager)

  local manager_version="${statuses[manager_version]}"
  local title=$(is_set $manager_version \
    && echo "${BLUE}${BOLD}$manager${NO_COLOR} ($manager_version)" \
    || echo "${BLUE}${BOLD}$manager${NO_COLOR} (...)")
  table_print "$title" headers[@] levels[@] messages[@]
}

status_get_manager_version() {
  local manager=$1

  local version=$(${manager}_version)

  until [ -p $fifo ]; do sleep 0.1; done
  echo "manager_version,$version" >$fifo
}

status_get_local_version() {
  local dependency=$1

  local version="NONE"
  ${manager}_is_installed $dependency && version=$(${manager}_get_local_version $dependency)

  until [ -p $fifo ]; do sleep 0.1; done
  echo "${dependency}_local_version,$version" >$fifo
}

status_get_remote_version() {
  local dependency=$1

  local version=$(${manager}_get_remote_version $dependency)
  ! is_set $version && version="NONE"

  until [ -p $fifo ]; do sleep 0.1; done
  echo "${dependency}_remote_version,$version" >$fifo
}

run_status() {
  local manager=$1
  local file=$(get_path $manager)
  local title="${BLUE}${BOLD}$manager${NO_COLOR}"
  local headers=("${BLUE}${BOLD}Package${NO_COLOR}" "${BLUE}${BOLD}Local${NO_COLOR}" "${BLUE}${BOLD}Remote${NO_COLOR}")
  local levels=()
  local messages=()

  [ -p $fifo ] && rm $fifo

  status_get_manager_version $manager &

  local i=0
  while IFS=, read -a line; do
    local dependency=${line[0]}
    ! is_set $dependency && continue

    status_get_local_version  $dependency &
    status_get_remote_version $dependency &

    i=$(($i + 1))
    continue

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
  done < <(read_csv $manager)

  status_update_table $manager 0
  mknod $fifo p

  local j=0
  while read data; do
    j=$(($j + 1))

    local array
    IFS=, read -r -a array <<< "$data"
    statuses["${array[0]}"]="${array[1]}"
    status_update_table $manager $(($i + 3))
    (( $j == $(($i * 2 + 1)) )) && break
  done <$fifo
}

