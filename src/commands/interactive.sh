# shellcheck shell=bash

command.interactive() {
  local managers
  local length
  managers=("$SYSTEM_MANAGER" "${NON_SYSTEM_MANAGERS[@]}")
  length=$(array.length managers[@])

  # Ask for CSVs
  for i in $(seq 0 $((length - 1))); do
    local manager="${managers[$i]}"

    [[ $i != 0 ]] && print.separator
    print.info "${BOLD}$manager${NO_COLOR}"

    local path
    local is_ignored
    local exists
    local default_path
    local default_color
    path=$(core.csv.path "$manager")
    is_ignored=$(core.manager.is_ignored "$manager" && echo true || echo false)
    exists=$(core.csv.exists "$manager" false && echo true || echo false)

    # Default value for prompt is the path if exists, ignore
    default_path="ignore"
    default_color="${BLUE}"
    if ! $is_ignored && $exists; then
      default_color="$GREEN"
      default_path="$path"
    fi

    local first=true
    while $first || (! $is_ignored && ! $exists); do
      local message
      local new_path

      # On the first run, print error if supplied path does not exists
      if $first && ! $is_ignored && ! $exists; then
        print.error "${RED}$path${NO_COLOR} not found"
      fi

      # Ask for path
      message="CSV (${default_color}$default_path${NO_COLOR}):"
      new_path=$(print.input 0 "$message")
      [[ "$new_path" =~ ^$ ]] && new_path="$default_path"
      CSVS[$manager]="$new_path"

      # Update
      path=$(core.csv.path "$manager")
      is_ignored=$(core.manager.is_ignored "$manager" && echo true || echo false)
      exists=$(core.csv.exists "$manager" false && echo true || echo false)

      # Redraw
      print.clear.line
      if $is_ignored; then
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

  # Carriage return if user did not press enter
  [[ ! "$cmd" =~ ^$ ]] && echo

  if   [[ "$cmd" =~ ^[i]$ ]]; then COMMAND="install"
  elif [[ "$cmd" =~ ^[u]$ ]]; then COMMAND="update"
  else                             COMMAND="status"
  fi

  # Redraw with answer
  print.clear.line
  print.fake.input "$message" "${BOLD}${YELLOW}$COMMAND${NO_COLOR}"

  # Ask for flags
  if [[ $COMMAND != "status" ]]; then
    local message="${BOLD}Flags?${NO_COLOR} "
    message+="(${BOLD}${YELLOW}q${NO_COLOR}uiet/"
    message+="${BOLD}${YELLOW}y${NO_COLOR}es/"
    message+="${BOLD}${YELLOW}s${NO_COLOR}imulate)"

    local flags
    flags=$(print.input 3 "$message")

    # Carriage return if user did not press enter
    (( $(string.length "$flags") == 3 )) && echo

    local answer=""
    if [[ "$flags" =~ [qQ] ]]; then QUIET=true   ; answer+="quiet "   ; fi
    if [[ "$flags" =~ [yY] ]]; then YES=true     ; answer+="yes "     ; fi
    if [[ "$flags" =~ [sS] ]]; then SIMULATE=true; answer+="simulate "; fi

    # Redraw with answer (interactive should neven be quiet)
    print.clear.line
    print.fake.input "$message" "${BOLD}${YELLOW}$answer${NO_COLOR}"
  fi
}

