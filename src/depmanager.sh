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
# shellcheck source=core/dir.sh
. ""
# shellcheck source=core/csv.sh
. ""
# shellcheck source=core/manager.sh
. ""
# shellcheck source=core/package.sh
. ""
# shellcheck source=managers/apt.sh
. ""
# shellcheck source=managers/npm.sh
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
main.parse_args() {
  # Print summary, version and help
  if (( $# == 0 )); then
    print.summary
    echo
    print.help
    exit
  elif (( $# == 1 )); then
    if string.equals "$1" "-v" || string.equals "$1" "--version"; then
      print.version
      exit
    elif string.equals "$1" "-h" || string.equals "$1" "--help"; then
      print.help
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
      print.error "Unknown command: $1"
      exit
  esac

  # Get options
  while [[ $# -gt 1 ]]; do
    case "$2" in
      -a|--apt)
        CSVS[apt]="$3"; shift; shift;;
      -y|--yum)
        CSVS[yum]="$3"; shift; shift;;
      -p|--pacman)
        CSVS[pacman]="$3"; shift; shift;;
      -n|--npm)
        CSVS[npm]="$3"; shift; shift;;
      -r|--rust)
        CSVS[rust]="$3"; shift; shift;;
      -Q|--quiet)
        QUIET=true; shift;;
      -Y|--yes)
        YES=true; shift;;
      -S|--simulate)
        SIMULATE=true; shift;;
      -*)
        if string.equals "$2" "-"; then
          print.error "There might be an error in your command, found a lone '-'"
          exit
        fi

        local flags
        local non_flags
        flags=$(string.slice "$2" 1)
        non_flags=$(string.replace "$flags" "[QYS]")

        string.contains "$flags" "Q" && QUIET=true
        string.contains "$flags" "Y" && YES=true
        string.contains "$flags" "S" && SIMULATE=true

        if ! string.is_empty "$non_flags"; then
          print.error "Unknown flags: ${BOLD}$non_flags${NO_COLOR}"
          exit
        fi

        shift;;
      *)
        print.error "Unknown option: ${BOLD}$2${NO_COLOR}"
        exit
    esac
  done
}

#
# Runs $COMMAND for each managers
#
main.run() {
  # User's system managers only and other managers
  declare -a managers
  managers=("$SYSTEM_MANAGER" "${NON_SYSTEM_MANAGERS[@]}")

  local length
  length=$(array.length managers[@])

  # For each managers
  for i in $(seq 0 $((length - 1))); do
    local manager="${managers[$i]}"

    # Pass if is bypassed or CSV not found
    core.manager.is_bypassed "$manager" && continue
    core.csv.exists          "$manager" || continue
    [[ $i != 0 ]] && print.separator

    # Pass with warning if manager is not found
    if ! core.manager.exists "$manager"; then
      print.warning "${BOLD}$manager${NO_COLOR} not found"
      continue
    fi

    # Write caches
    core.manager.version "$manager" > /dev/null
    core.csv.get         "$manager" > /dev/null

    # Run command for manager if CSV contains data,
    # or print warning
    if core.csv.is_empty "$manager"; then
      print.warning "${BOLD}${BLUE}$manager${NO_COLOR} CSV is empty"
    else
      command.${COMMAND} "$manager"
    fi
  done
}

#
# Main
# Parses arguments, resolves files, run specified command
#
main() {
  main.parse_args "$@"
  core.dir.resolve
  core.manager.system

  if [[ "$COMMAND" == "interactive" ]]; then
    QUIET=false
    YES=false
  fi

  print.system_info
  print.separator

  if [[ "$COMMAND" == "interactive" ]]; then
    command.interactive
    print.separator
  fi

  print.csvs_info
  print.separator

  if [[ $COMMAND == "status" ]]; then
    local old_quiet=$QUIET
    QUIET=false
    main.run
    QUIET=$old_quiet
  else
    if print.pre_run_confirm; then
      print.info Go!
      print.separator
      main.run
    else
      print.info Bye!
      exit
    fi
  fi

  print.separator
  print.info Done!
}

# Run
main "$@"

