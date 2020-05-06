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

  for manager in "${managers[@]}"; do
    is_bypassed $manager      && continue
    ! detect_manager $manager && continue
    ! detect_path $manager    && continue

    print_separator
    print_info ${BOLD}$manager${NO_COLOR}

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

  while IFS=, read -a line; do
    local dependency=${line[0]}
    local installed=false
    local local_version="NONE"
    local remote_version=$(${manager}_get_remote_version $dependency)
    ! is_set $remote_version && remote_version="NONE"

    if ${manager}_is_installed $dependency; then
      installed=true
      local_version=$(${manager}_get_local_version $dependency)
    fi

    local msg="$dependency \t\t $local_version \t\t $remote_version"

    if ! $installed; then
      print_error $msg
    elif [[ $local_version == $remote_version ]]; then
      print_success $msg
    else
      print_warning $msg
    fi
  done < $file
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
  # local arr=(
    # "info a bb ccc"
    # "success aa bb cc"
    # "warning aaa bbb ccc"
    # "info a b c"
    # "success aa bb cc"
    # "warning aaa bbb ccc"
  # )

  # local a=$(echo "${arr[@]}" | column -s ' ' -t)
  # for i in ${a[@]}; do
    # echo $i
  # done
  arr="info aaaaaa b c success aa bb cc warning aaa bbb ccc"
  print_justified 3 4 "$arr"
  exit

  parse_args $@
  resolve_dir
  detect_system

  for manager in "${MANAGERS[@]}"; do
    is_bypassed $manager && continue

    resolve_path $manager
    detect_path $manager
    detect_manager $manager
  done

  if print_pre_run; then
    print_info Go!
    run
    # run_${COMMAND}
  else
    print_info Bye!
    exit
  fi
}

# Run
main $@

