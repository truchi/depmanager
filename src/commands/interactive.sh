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
        print.warning "${RED}$path${NO_COLOR} not found"
      fi

      # Ask for path
      message="CSV (${default_color}$default_path${NO_COLOR}):"
      print.input 0 "$message"
      new_path="$REPLY"
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
        print.warning "$message ${RED}$path${NO_COLOR}"
      fi

      first=false
    done
  done

  print.separator

  # Ask for command
  local options=("Status" "install" "update")
  print.choice 1 "${BOLD}Command?${NO_COLOR}" options[@]
  COMMAND="$REPLY"

  [[ $COMMAND == "status" ]] && return

  # Ask for flags
  local options=()
  $_QUIET    && options+=("Quiet")    || options+=("quiet")
  $_YES      && options+=("Yes")      || options+=("yes")
  $_SIMULATE && options+=("Simulate") || options+=("simulate")

  print.choice 3 "${BOLD}Flags?${NO_COLOR}" options[@]
  string.contains "$REPLY" "quiet"    && QUIET=true
  string.contains "$REPLY" "yes"      && YES=true
  string.contains "$REPLY" "simulate" && SIMULATE=true
}

