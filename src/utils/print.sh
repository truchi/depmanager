#!/bin/bash

print_date() {
  echo ${MAGENTA}[$(date +"%Y-%m-%d %H:%M:%S")]${NO_COLOR}
}

print_error() {
  echo "$(print_date) ${RED}✗${NO_COLOR} $@"
}

print_warning() {
  if $QUIET; then return; fi
  echo "$(print_date) ${YELLOW}!${NO_COLOR} $@"
}

print_success() {
  if $QUIET; then return; fi
  echo "$(print_date) ${GREEN}✔${NO_COLOR} $@"
}

print_info() {
  if $QUIET; then return; fi
  echo "$(print_date) ${BLUE}${BOLD}i${NO_COLOR} $@"
}

print_confirm() {
  if $YES; then
    return 0
  fi

  local message="$(print_date) ${YELLOW}${BOLD}?${NO_COLOR} ${BOLD}$1${NO_COLOR} ${YELLOW}(Y)${NO_COLOR}"

  read -p "$message " -n 1 -r

  if [[ ! "$REPLY" =~ ^$ ]]
  then
    echo
  fi

  if [[ "$REPLY" =~ ^[Yy]$ || "$REPLY" =~ ^$ ]]
  then
    return 0
  else
    return 1
  fi
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
  for type in "${TYPES[@]}"; do
    local message="${BOLD}$type${NO_COLOR}: "
    local file="${ARG[$type]}"
    local bypass="${BYPASS[$type]}"
    local found="${FOUND[$type]}"
    local proceed="${PROCEED[$type]}"

    if is_system_type "$type" && [[ "${DETECT[$type]}" != true ]]; then
      continue
    fi

    if $bypass; then
      message="$message bypassed"
    else
      if $found; then
        message="$message ${GREEN}✔${NO_COLOR} ($file)"
      else
        message="$message ${RED}✗${NO_COLOR} ($file)"
      fi
    fi

    if $bypass; then
      print_info $message
    elif $proceed; then
      print_success $message
    else
      print_warning $message
    fi
  done
}
