#!/bin/bash

#
# Parses args, filling the appropriate global variables
#
parse_args() {
  # Print summary, version and help
  if [[ $# == 0 ]]; then
    print_summary
    echo
    print_help
    exit
  elif [[ $# == 1 ]]; then
    if [[ "$1" == "--version" || "$1" == "-v" ]]; then
      print_version
      exit
    elif [[ "$1" == "--help" || "$1" == "-h" ]]; then
      print_help
      exit
    fi
  fi

  # Get command
  case "$1" in
    s|status)
      COMMAND="status";;
    i|install)
      COMMAND="install";;
    u|update)
      COMMAND="update";;
    *)
      print_error Unknown command: $1
      exit
  esac

  # Get options
  while [[ $# -gt 1 ]]; do
    case "$2" in
      -a|--apt)
        PATHS[apt]="$3"; shift; shift;;
      -y|--yum)
        PATHS[yum]="$3"; shift; shift;;
      -p|--pacman)
        PATHS[pacman]="$3"; shift; shift;;
      -n|--node)
        PATHS[node]="$3"; shift; shift;;
      -r|--rust)
        PATHS[rust]="$3"; shift; shift;;
      -Q|--quiet)
        QUIET=true; shift;;
      -Y|--yes)
        YES=true; shift;;
      -S|--simulate)
        SIMULATE=true; shift;;
      -*)
        if [[ "$2" = "-" ]]; then
          print_error "There might be an error in your command, found a lone '-'"
          exit
        fi

        local flags="${2:1}"
        local non_flags=$(echo "$flags" | sed 's/[QYS]//g')

        [[ "$flags" == *"Q"* ]] && QUIET=true
        [[ "$flags" == *"Y"* ]] && YES=true
        [[ "$flags" == *"S"* ]] && SIMULATE=true

        if is_set "$non_flags"; then
          print_error "Unknown flags: ${BOLD}$non_flags${NO_COLOR}"
          exit
        fi

        shift;;
      *)
        print_error "Unknown option: ${BOLD}$2${NO_COLOR}"
        exit
    esac
  done
}

run() {
  local managers=($SYSTEM_MANAGER "${NON_SYSTEM_MANAGERS[@]}")
  local length=$(array_length managers[@])

  for i in $(seq 0 $(($length - 1))); do
    local manager="${managers[$i]}"
    is_bypassed $manager      && continue
    ! detect_path $manager    && continue
    ! detect_manager $manager && continue


    [[ $i != 0 ]] && print_separator
    run_${COMMAND} $manager

    # continue
    # if command_exists ${manager}_${COMMAND}; then
      # ${manager}_${COMMAND}
    # else
      # print_warning "Oops! $COMMAND is not implemented for ${manager}, ..."
    # fi
  done
}

run_status() {
  local manager=$1
  local file=$(get_path $manager)
  local title="${BLUE}${BOLD}$manager${NO_COLOR}"
  local headers=("${BLUE}${BOLD}Package${NO_COLOR}" "${BLUE}${BOLD}Local${NO_COLOR}" "${BLUE}${BOLD}Remote${NO_COLOR}")
  local messages=()

  local i=1
  while IFS=, read -a line; do
    local dependency=${line[0]}
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
  done < $file

  table_print "$title" headers[@] levels[@] messages[@]
}

run_install() {
  echo INSTALL
}

run_update() {
  echo UPDATE
}

#
# Main
# Parses arguments, resolves files, run specified command
#
main() {
  parse_args $@
  resolve_dir
  detect_system

  for manager in "${MANAGERS[@]}"; do
    is_bypassed $manager && continue

    resolve_path $manager
    detect_path $manager
    detect_manager $manager
  done

  print_system_info
  print_separator
  print_csv_info
  print_separator

  if [[ $COMMAND == "status" ]]; then
    local old_quiet=$QUIET
    QUIET=false
    run
    QUIET=$old_quiet
  else
    if print_pre_run_confirm; then
      print_info Go!
      run
    else
      print_info Bye!
      exit
    fi
  fi

  print_separator
  print_info Done!
}

# Run
main $@

