# shellcheck shell=bash
# shellcheck source=header.sh
. ""
# shellcheck source=vars.sh
. ""
# shellcheck source=utils/helpers.sh
. ""
# shellcheck source=utils/string.sh
. ""
# shellcheck source=utils/array.sh
. ""
# shellcheck source=utils/print.sh
. ""
# shellcheck source=utils/table.sh
. ""
# shellcheck source=utils/functions.sh
. ""
# shellcheck source=managers/apt.sh
. ""
# shellcheck source=managers/node.sh
. ""
# shellcheck source=commands/interactive.sh
. ""
# shellcheck source=commands/status.sh
. ""
# shellcheck source=commands/install.sh
. ""
# shellcheck source=commands/update.sh
. ""

#
# Parses args, filling the appropriate global variables
#
parse_args() {
  # Print summary, version and help
  if (( $# == 0 )); then
    print_summary
    echo
    print_help
    exit
  elif (( $# == 1 )); then
    if string_equals "$1" "-v" || string_equals "$1" "--version"; then
      print_version
      exit
    elif string_equals "$1" "-h" || string_equals "$1" "--help"; then
      print_help
      exit
    fi
  fi

  # Get command
  case "$1" in
    I|interactive)
      COMMAND="interactive";;
    s|status)
      COMMAND="status";;
    i|install)
      COMMAND="install";;
    u|update)
      COMMAND="update";;
    *)
      print_error "Unknown command: $1"
      exit
  esac

  # Get options
  while [[ $# -gt 1 ]]; do
    case "$2" in
      -a|--apt)
        PATHS["apt"]="$3"; shift; shift;;
      -y|--yum)
        PATHS["yum"]="$3"; shift; shift;;
      -p|--pacman)
        PATHS["pacman"]="$3"; shift; shift;;
      -n|--node)
        PATHS["node"]="$3"; shift; shift;;
      -r|--rust)
        PATHS["rust"]="$3"; shift; shift;;
      -Q|--quiet)
        QUIET=true; shift;;
      -Y|--yes)
        YES=true; shift;;
      -S|--simulate)
        SIMULATE=true; shift;;
      -*)
        if string_equals "$2" "-"; then
          print_error "There might be an error in your command, found a lone '-'"
          exit
        fi

        local flags
        local non_flags
        flags=$(string_substring "$2" 1)
        non_flags=$(string_replace "$flags" "[QYS]")

        string_contains "$flags" "Q" && QUIET=true
        string_contains "$flags" "Y" && YES=true
        string_contains "$flags" "S" && SIMULATE=true

        if ! string_is_empty "$non_flags"; then
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
  declare -a managers
  local length
  managers=("$SYSTEM_MANAGER" "${NON_SYSTEM_MANAGERS[@]}")
  length=$(array_length managers[@])

  for i in $(seq 0 $((length - 1))); do
    local manager="${managers[$i]}"

    is_bypassed "$manager"      && continue
    ! detect_path "$manager"    && continue

    [[ $i != 0 ]] && print_separator
    ! detect_manager "$manager" && print_warning "${BOLD}$manager${NO_COLOR} not found" && continue

    if csv_is_empty "$manager"; then
      print_warning "${BOLD}${BLUE}$manager${NO_COLOR} CSV is empty"
    else
      run_${COMMAND} "$manager"
    fi
  done
}

#
# Main
# Parses arguments, resolves files, run specified command
#
main() {
  parse_args "$@"
  resolve_dir
  detect_system

  if [[ "$COMMAND" == "interactive" ]]; then
    QUIET=false
    YES=false
  fi

  print_system_info
  print_separator

  for manager in "${MANAGERS[@]}"; do
    is_bypassed "$manager" && continue

    resolve_path "$manager"
    detect_path "$manager"
  done

  if [[ "$COMMAND" == "interactive" ]]; then
    run_interactive
    print_separator
  fi

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
      print_separator
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
main "$@"

