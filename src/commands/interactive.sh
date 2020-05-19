# shellcheck shell=bash

command.interactive() {
  local managers
  local length
  managers=("$SYSTEM_MANAGER" "${NON_SYSTEM_MANAGERS[@]}")
  length=$(array.length managers[@])

  for i in $(seq 0 $((length - 1))); do
    local manager="${managers[$i]}"

    [[ $i != 0 ]] && print.separator
    print.info "${BOLD}$manager${NO_COLOR}"

    local first=true
    local path
    local default_path=false
    local color="$BLUE"

    while true; do
      if core.manager.is_bypassed "$manager"; then
        default_path=false
        color="$BLUE"
      else
        core.csv.resolve "$manager"

        if core.csv.exists "$manager" false; then
          ! $first && break
          default_path=$(core.csv.path "$manager")
          color="$GREEN"
        else
          print.warning "${YELLOW}$path${NO_COLOR} not found"
          default_path=false
          color="$BLUE"
        fi
      fi

      path=$(print.input 0 "CSV (${color}$default_path${NO_COLOR}):")
      [[ "$path" =~ ^$ ]] && path="$default_path"
      CSVS[$manager]=$path

      [[ "$path" == false ]] && break
      first=false
    done
  done

  print.separator

  # Ask for command
  local message="${BOLD}Command?${NO_COLOR} "
  message+="(${BOLD}${YELLOW}S${NO_COLOR}tatus/"
  message+="${BOLD}${YELLOW}i${NO_COLOR}nstall/"
  message+="${BOLD}${YELLOW}u${NO_COLOR}pdate)"

  local cmd
  cmd=$(print.input 1 "$message")

  if   [[ "$cmd" =~ ^[i]$ ]]; then COMMAND="install"
  elif [[ "$cmd" =~ ^[u]$ ]]; then COMMAND="update"
  else                             COMMAND="status"
  fi

  # Carriage return if user did not press enter
  [[ ! "$cmd" =~ ^$ ]] && echo

  # Ask for simulate
  if [[ $COMMAND != "status" ]] && print.confirm "Simulate?"; then
    SIMULATE=true
  fi
}

