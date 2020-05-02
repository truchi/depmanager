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

        if [[ "$flags" == *"Q"* ]]; then
          QUIET=true
        fi
        if [[ "$flags" == *"Y"* ]]; then
          YES=true
        fi
        if [[ "$flags" == *"S"* ]]; then
          SIMULATE=true
        fi

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
  for type in "${TYPES[@]}"; do
    echo type:$type
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

  for type in "${TYPES[@]}"; do
    if [[ "${ARG[$type]}" = "false" ]]; then
      BYPASS[$type]=true
    else
      make_path "$type"
      check_file "$type"
    fi

    if ! ${BYPASS[$type]} && ${FOUND[$type]}; then
      PROCEED[$type]=true
    fi
  done

  for type in "${SYSTEM_TYPES[@]}"; do
    detect_manager "$type"
  done

  print_pre_proceed_message

  local confirm_message="Proceed for $COMMAND?"
  if $SIMULATE; then
    confirm_message="Simulate $COMMAND?"
  fi

  if print_confirm "$confirm_message"; then
    print_info Go!
  else
    print_info Bye!
  fi
  exit

  # proceed
}

# Run
main $@

