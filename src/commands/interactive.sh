#!/bin/bash

run_interactive() {
  local managers=($SYSTEM_MANAGER "${NON_SYSTEM_MANAGERS[@]}")
  local length=$(array_length managers[@])

  for i in $(seq 0 $(($length - 1))); do
    local ok=false
    local manager="${managers[$i]}"
    ! detect_manager $manager && continue

    [[ $i != 0 ]] && print_separator
    print_info "${BOLD}$manager${NO_COLOR}"

    local first=true
    local path
    local default_path

    while true; do
      if is_bypassed $manager; then
        default_path="${BLUE}false${NO_COLOR}"
      else
        resolve_path $manager

        if detect_path $manager false; then
          ! $first && break
          default_path="${GREEN}${PATHS[$manager]}${NO_COLOR}"
        else
          default_path="${BLUE}false${NO_COLOR}"
          print_warning "Not found ${YELLOW}${PATHS[$manager]}${NO_COLOR}"
        fi
      fi

      path=$(print_input "CSV ($default_path):")
      [[ "$path" =~ ^$ ]] && path=$(string_strip_sequences $default_path)
      PATHS[$manager]=$path

      [[ "$path" == false ]] && break
      first=false
    done
  done

  # TODO ask for action
}
