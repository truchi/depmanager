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
  if [[ "$1" == "check" || "$1" == "c" ]]; then
    COMMAND="check"
  elif [[ "$1" == "diff" || "$1" == "d" ]]; then
    COMMAND="diff"
  elif [[ "$1" == "install" || "$1" == "i" ]]; then
    COMMAND="install"
  elif [[ "$1" == "update" || "$1" == "u" ]]; then
    COMMAND="update"
  else
    print_error Unknown command: $1
    exit
  fi

  # Get options
  while [[ $# -gt 1 ]]; do
    case "$2" in
      -a|--apt)
        ARG[apt]="$3"; shift; shift;;
      -y|--yum)
        ARG[yum]="$3"; shift; shift;;
      -p|--pacman)
        ARG[pacman]="$3"; shift; shift;;
      -n|--node)
        ARG[node]="$3"; shift; shift;;
      -r|--rust)
        ARG[rust]="$3"; shift; shift;;
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

proceed() {
  for manager in "${MANAGERS[@]}"; do
    echo manager:$manager
  done
}

#
# Main
# Parses arguments, resolves files, run specified command
#
main() {
  parse_args $@
  get_dir
  print_info "${BOLD}Depmanager directory${NO_COLOR}: ${ARG[dir]}"

  for manager in "${MANAGERS[@]}"; do
    if [[ "${ARG[$manager]}" = "false" ]]; then
      BYPASS[$manager]=true
    else
      make_path "$manager"
      check_file "$manager"
    fi

    is_system_manager $manager && detect_manager "$manager"
  done

  print_pre_proceed_message

  local confirm_message="Proceed for $COMMAND?"
  $SIMULATE && confirm_message="Simulate $COMMAND?"

  if print_confirm "$confirm_message"; then
    print_info Go!
    proceed
  else
    print_info Bye!
    exit
  fi
}

# Run
main $@

