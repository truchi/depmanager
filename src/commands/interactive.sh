# shellcheck shell=bash

command.interactive() {
  local managers
  local length
  managers=("$SYSTEM_MANAGER" "${NON_SYSTEM_MANAGERS[@]}")
  length=$(array.length managers[@])

  for i in $(seq 0 $((length - 1))); do
    local manager="${managers[$i]}"
    core.manager.exists "$manager" || continue

    [[ $i != 0 ]] && print.separator
    print.info "${BOLD}$manager${NO_COLOR}"

    local first=true
    local path
    local default_path=false
    local color="$BLUE"

    while true; do
      if ! core.manager.is_bypassed "$manager"; then
        core.csv.resolve "$manager"

        if core.csv.exists "$manager" false; then
          ! $first && break
          default_path=$(core.csv.path "$manager")
          color="$GREEN"
        else
          print.warning "Not found ${YELLOW}$path${NO_COLOR}"
        fi
      fi

      path=$(print.input "CSV (${color}$default_path${NO_COLOR}):")
      [[ "$path" =~ ^$ ]] && path="$default_path"
      CSVS[$manager]=$path

      [[ "$path" == false ]] && break
      first=false
    done
  done

  # TODO ask for action
}
