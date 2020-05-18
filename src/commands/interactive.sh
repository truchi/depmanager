# shellcheck shell=bash

run_interactive() {
  local managers
  local length
  managers=("$SYSTEM_MANAGER" "${NON_SYSTEM_MANAGERS[@]}")
  length=$(array.length managers[@])

  for i in $(seq 0 $((length - 1))); do
    local manager="${managers[$i]}"
    ! core.detect_manager "$manager" && continue

    [[ $i != 0 ]] && print.separator
    print.info "${BOLD}$manager${NO_COLOR}"

    local first=true
    local path
    local default_path

    while true; do
      if core.is_bypassed "$manager"; then
        default_path="${BLUE}false${NO_COLOR}"
      else
        core.resolve_path "$manager"

        if core.detect_path "$manager" false; then
          ! $first && break
          default_path="${GREEN}${PATHS[$manager]}${NO_COLOR}"
        else
          default_path="${BLUE}false${NO_COLOR}"
          print.warning "Not found ${YELLOW}${PATHS[$manager]}${NO_COLOR}"
        fi
      fi

      path=$(print.input "CSV ($default_path):")
      [[ "$path" =~ ^$ ]] && path=$(string.strip_sequences "$default_path")
      PATHS[$manager]=$path

      [[ "$path" == false ]] && break
      first=false
    done
  done

  # TODO ask for action
}
