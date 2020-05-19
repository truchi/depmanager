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

    local path
    local is_bypassed
    local exists
    local default_path
    local default_color
    path=$(core.csv.path "$manager")
    is_bypassed=$(core.manager.is_bypassed "$manager" && echo true || echo false)
    exists=$(core.csv.exists "$manager" false && echo true || echo false)

    # Default value for prompt is the path if exists, false (bybpass otherwise)
    default_path=false
    default_color="${BLUE}"
    if ! $is_bypassed && $exists; then
      default_color="$GREEN"
      default_path="$path"
    fi

    local first=true
    while $first || (! $is_bypassed && ! $exists); do
      local message
      local color
      local new_path

      # On the first run, print error if supplied path does not exists
      if $first && ! $is_bypassed && ! $exists; then
        print.error "${RED}$path${NO_COLOR} not found"
      fi

      # Ask for path
      message="CSV (${default_color}$default_path${NO_COLOR}):"
      new_path=$(print.input 0 "$message")
      [[ "$new_path" =~ ^$ ]] && new_path="$default_path"
      CSVS[$manager]="$new_path"

      # Update
      path=$(core.csv.path "$manager")
      is_bypassed=$(core.manager.is_bypassed "$manager" && echo true || echo false)
      exists=$(core.csv.exists "$manager" false && echo true || echo false)

      # Redraw
      tput cuu1
      tput el
      if $is_bypassed; then
        print.info "$message ${BLUE}$path${NO_COLOR}"
      elif $exists; then
        print.success "$message ${GREEN}$path${NO_COLOR}"
      else
        print.error "$message ${RED}$path${NO_COLOR}"
      fi

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

  # Redraw with answer
  tput cuu1
  print.fake.input "$message" "${BOLD}${YELLOW}$COMMAND${NO_COLOR}"

  # Ask for simulate
  if [[ $COMMAND != "status" ]] && print.confirm "Simulate?"; then
    SIMULATE=true
  fi
}

