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
      -d|--dir)
        ARG[DIR]="$3"; shift; shift;;
      -s|--system)
        ARG[SYSTEM]="$3"; shift; shift;;
      -n|--node)
        ARG[NODE]="$3"; shift; shift;;
      -r|--rust)
        ARG[RUST]="$3"; shift; shift;;
      -q|--quiet)
        QUIET=true; shift;;
      -y|--yes)
        YES=true; shift;;
      *)
        print_error Unknown option: $key
        exit
    esac
  done
}

#
# Main
# Parses arguments, resolves files, run specified command
#
main() {
  parse_args $@
  get_dir

  local dir="${ARG[dir]}"
  print_info Depmanager directory: $dir

  for type in "${TYPES[@]}"; do
    make_path "$type"
    check_file "$type"
    detect_manager "$type"

    local message=""
    local file="${ARG[$type]}"
    local found="${FOUND[$type]}"
    local detect="${DETECT[$type]}"

    if $detect; then
      message="manager found, "
    else
      message="manager NOT found, "
    fi

    if $found; then
      message="$message file found ($file)."
    else
      message="$message file NOT found ($file)."
    fi

    if $detect && $found; then
      print_success $type: $message Will proceed.
    else
      print_warning $type: $message Will NOT proceed.
    fi
  done



  # if [[ $QUIET == false ]]; then
    # echo lol
  # else
    # echo suposed quiet
  # fi

  # for a in "${name[@]}"; do
    # echo $a
  # done

  # get_dir
  # echo $DIR

  # get_deps SYSTEM
  # echo SYSTEM: $SYSTEM
}

# Run
main $@

