#!/bin/bash

print_date() {
  echo ${MAGENTA}[$(date +"%Y-%m-%d %H:%M:%S")]${NO_COLOR}
}

print_error() {
  echo "$(print_date) ${RED}✗${NO_COLOR} $@"
}

print_warning() {
  $QUIET && return
  echo "$(print_date) ${YELLOW}!${NO_COLOR} $@"
}

print_success() {
  $QUIET && return
  echo "$(print_date) ${GREEN}✔${NO_COLOR} $@"
}

print_info() {
  $QUIET && return
  echo "$(print_date) ${BLUE}${BOLD}i${NO_COLOR} $@"
}

print_confirm() {
  # Auto confirm if flag is given
  $YES && return

  # Prompt confirmation message
  local message="$(print_date) ${YELLOW}${BOLD}?${NO_COLOR} ${BOLD}$1${NO_COLOR} ${YELLOW}(Y)${NO_COLOR}"
  read -p "$message " -n 1 -r

  # Carriage return if user did not press enter
  [[ ! "$REPLY" =~ ^$ ]] && echo

  # Accepts <Enter>, Y or y
  [[ "$REPLY" =~ ^[Yy]$ || "$REPLY" =~ ^$ ]]
}

print_version() {
  echo "${YELLOW}v0.0.1${NO_COLOR}"
}

print_summary () {
  echo "${BOLD}${GREEN}depmanager${NO_COLOR} $(print_version)
${MAGENTA}https://github.com/truchi/depmanager${NO_COLOR}"
}

print_help() {
  local command=$(basename $0)

  echo "${BOLD}${BLUE}Usage:${NO_COLOR}
  ${BOLD}${GREEN}$command${NO_COLOR} [-h|--version]
  ${BOLD}${GREEN}$command${NO_COLOR} [-v|--help]
  ${BOLD}${GREEN}$command${NO_COLOR} <command> [options]

${BOLD}${BLUE}Description:${NO_COLOR}
  ${WHITE}Manages your dependencies.

  List packages you depend on in CSV files (system.csv, node.csv, rust.csv).
  Export \$DEPMANAGER_DIR (containing these files) environment variable (defaults to \$HOME/.config/depmanager).${NO_COLOR}

${BOLD}${BLUE}Commands:${NO_COLOR}
  c${WHITE},${NO_COLOR} check                       ${WHITE}Produces a report with regard to the CSV files${NO_COLOR}
  d${WHITE},${NO_COLOR} diff                        ${WHITE}List installed packages yet not in the CSV files${NO_COLOR}
  i${WHITE},${NO_COLOR} install                     ${WHITE}Installs packages in the CSV files${NO_COLOR}
  u${WHITE},${NO_COLOR} update                      ${WHITE}Updates packages in the CSV files${NO_COLOR}

${BOLD}${BLUE}Options:${NO_COLOR}
  -a${WHITE},${NO_COLOR} --apt <path|url|false>     ${WHITE}Blah${NO_COLOR}
  -y${WHITE},${NO_COLOR} --yum <path|url|false>     ${WHITE}Blah${NO_COLOR}
  -p${WHITE},${NO_COLOR} --pacman <path|url|false>  ${WHITE}Blah${NO_COLOR}
  -n${WHITE},${NO_COLOR} --node <path|url|false>    ${WHITE}Blah${NO_COLOR}
  -r${WHITE},${NO_COLOR} --rust <path|url|false>    ${WHITE}Blah${NO_COLOR}
  -Q${WHITE},${NO_COLOR} --quiet                    ${WHITE}Blah${NO_COLOR}
  -Y${WHITE},${NO_COLOR} --yes                      ${WHITE}Blah${NO_COLOR}
  -S${WHITE},${NO_COLOR} --simulate                 ${WHITE}Blah${NO_COLOR}

${BOLD}${BLUE}Links:${NO_COLOR}
  ${WHITE}- Repository${NO_COLOR}             ${MAGENTA}https://github.com/truchi/depmanager${NO_COLOR}
  ${WHITE}- Website${NO_COLOR}                ${MAGENTA}https://github.com/truchi/depmanager${NO_COLOR}
  ${WHITE}- Documentation${NO_COLOR}          ${MAGENTA}https://github.com/truchi/depmanager${NO_COLOR}
"
}

print_pre_proceed_message () {
  print_info "${BOLD}Depmanager directory${NO_COLOR}: $(get_path dir)"

  for manager in "${MANAGERS[@]}"; do
    # Ignore system manager which are not detected on user's system
    if is_system_manager $manager; then
      detect_manager $manager
      [[ $(code_to_boolean $?) != true ]] && continue
    fi

    # Make message
    local message="${BOLD}$manager${NO_COLOR}: "
    if   is_bypassed $manager; then message="$message bypassed"
    elif detect_path $manager; then message="$message ${GREEN}✔${NO_COLOR} ($(get_path $manager))"
    else                            message="$message ${RED}✗${NO_COLOR} ($(get_path $manager))"
    fi

    # Print message
    if   is_bypassed $manager; then print_info    $message
    elif detect_path $manager; then print_success $message
    else                            print_warning $message
    fi
  done

  # Ask for confirmation
  $SIMULATE \
    && print_confirm "Simulate $COMMAND?" \
    || print_confirm "Proceed for $COMMAND"
}
