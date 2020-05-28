# shellcheck shell=bash
# shellcheck source=header.sh
. ""
# shellcheck source=vars.sh
. ""
# shellcheck source=utils/helpers.sh
. ""
# shellcheck source=utils/cache.sh
. ""
# shellcheck source=utils/cache.async.sh
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
      COMMAND="interactive"
      if ! $IN_TERMINAL; then
        print.error "Cannot run interactive outside of a terminal" 2
        exit 1
      fi
      ;;
    s|status)
      COMMAND="status";;
    i|install)
      COMMAND="install";;
    u|update)
      COMMAND="update";;
    *)
      print.error "Unknown command: $1" 2
      exit 1
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
          print.error "There might be an error in your command, found a lone '-'" 2
          exit 1
        fi

        local flags
        local non_flags
        flags=$(string.slice "$2" 1)
        non_flags=$(string.replace "$flags" "[QYS]")

        string.contains "$flags" "Q" && QUIET=true
        string.contains "$flags" "Y" && YES=true
        string.contains "$flags" "S" && SIMULATE=true

        if ! string.is_empty "$non_flags"; then
          print.error "Unknown flags: ${BOLD}$non_flags${NO_COLOR}" 2
          exit 1
        fi

        shift;;
      *)
        print.error "Unknown option: ${BOLD}$2${NO_COLOR}" 2
        exit 1
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
  local j=0
  for i in $(seq 0 $((length - 1))); do
    local manager="${managers[$i]}"

    # Pass if is ignored or CSV not found
    core.manager.is_ignored "$manager" && continue
    core.csv.exists         "$manager" || continue
    (( j != 0 )) && print.separator
    j=$((j + 1))

    # Pass with warning if manager is not found
    if ! core.manager.exists "$manager"; then
      print.warning "${BOLD}$manager${NO_COLOR} not found"
      continue
    fi

    # Run command for manager if CSV contains data,
    # or print warning
    if core.csv.is_empty "$manager"; then
      print.warning "${BOLD}${BLUE}$manager${NO_COLOR} CSV is empty"
    else
      command.${COMMAND} "$manager"
    fi
  done
}

main.force_flags() {
  # Force yes when not running in a terminal
  ! $IN_TERMINAL && YES=true
  # Simulate implies !quiet
  $SIMULATE && QUIET=false
  # Quiet implies yes
  $QUIET && YES=true
}

main.reset_flags() {
  _QUIET=$QUIET
  _YES=$YES
  _SIMULATE=$SIMULATE
  QUIET=false
  YES=false
  SIMULATE=false
}

#
# Main
# Parses arguments, resolves files, run specified command
#
main() {
  main.parse_args "$@"
  core.dir.resolve
  core.manager.system

  if [[ "$COMMAND" == "interactive" ]]; then main.reset_flags
  else                                       main.force_flags
  fi
  print.system_info
  print.separator

  # Run interactive (ask for CSV, command, and flags)
  if [[ "$COMMAND" == "interactive" ]]; then
    command.interactive
    print.separator
  fi

  main.force_flags
  print.csvs_info
  print.separator

  if [[ $COMMAND == "status" ]]; then
    # Status cannot be quiet
    local old_quiet=$QUIET
    QUIET=false
    main.run
    QUIET=$old_quiet
  else
    # Ask confirm
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

