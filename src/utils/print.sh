#!/bin/bash

print_separator() {
  $QUIET && return
  echo "${MAGENTA}~~~~~~~~~~~~~~~~~~~~~${NO_COLOR}"
}

print_date() {
  echo ${MAGENTA}[$(date +"%Y-%m-%d %H:%M:%S")]${NO_COLOR}
}

print_error() {
  echo "$(print_date) ${RED}${BOLD}✗${NO_COLOR} $@"
}

print_warning() {
  $QUIET && return
  echo "$(print_date) ${YELLOW}${BOLD}!${NO_COLOR} $@"
}

print_success() {
  $QUIET && return
  echo "$(print_date) ${GREEN}${BOLD}✔${NO_COLOR} $@"
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

print_summary() {
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
  s${WHITE},${NO_COLOR} status                      ${WHITE}Produces a report with regard to the CSV files${NO_COLOR}
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
  ${WHITE}- Repository${NO_COLOR}                   ${MAGENTA}https://github.com/truchi/depmanager${NO_COLOR}
  ${WHITE}- Website${NO_COLOR}                      ${MAGENTA}https://github.com/truchi/depmanager${NO_COLOR}
  ${WHITE}- Documentation${NO_COLOR}                ${MAGENTA}https://github.com/truchi/depmanager${NO_COLOR}
"
}

print_pre_run() {
  print_info "${BOLD}Depmanager directory${NO_COLOR}: ${BLUE}$(get_path dir)${NO_COLOR}"

  if is_set $SYSTEM_MANAGER; then
    local version=$($SYSTEM_MANAGER --version)
    print_info "${BOLD}Detected system's package manager${NO_COLOR}: ${BLUE}$SYSTEM_MANAGER${NO_COLOR} ($version)"
  else
    print_warning "${BOLD}Your system's package manager is not supported${NO_COLOR}"
  fi

  print_separator

  for manager in "${MANAGERS[@]}"; do
    # Ignore system manager which are not detected on user's system
    if is_system_manager $manager; then
      detect_manager $manager
      [[ $(code_to_boolean $?) != true ]] && continue
    fi

    # Make message
    local message="${BOLD}$manager${NO_COLOR} "
    if   is_bypassed $manager; then message="$message ${BLUE}bypassed${NO_COLOR}"
    elif detect_path $manager; then message="$message ${GREEN}$(get_path $manager)${NO_COLOR}"
    else                            message="$message ${YELLOW}$(get_path $manager)${NO_COLOR}"
    fi

    # Print message
    if   is_bypassed $manager; then print_info    $message
    elif detect_path $manager; then print_success $message
    else                            print_warning $message
    fi
  done

  print_separator

  ! $SIMULATE && print_info "(Tip: run with --simulate first)"

  # Ask for confirmation
  $SIMULATE \
    && print_confirm "Simulate $COMMAND?" \
    || print_confirm "Run $COMMAND?"
}

print_justified() {
  local arr=$@
  local n_rows=$1
  local n_cols=$2
  local max_lengths

  for i in $(seq 0 $(($n_cols - 1))); do
    local col=$(matrix_get_column $i $arr)
    local max_length=-1

    for word in $col; do
      local length=${#word}
      [[ $length > $max_length ]] && max_length=$length
    done

    max_lengths[$i]=$max_length
  done

  for i in $(seq 0 $(($n_rows - 1))); do
    local row=($(matrix_get_row $i $arr))
    local level="${row[0]}"
    local message=""

    for i in $(seq 1 $(($n_cols - 1))); do
      local cell=${row[$i]}
      local max_length=$((${max_lengths[$i]} + 2))
      message="$message$(printf "%-${max_length}s" "$cell")"
    done

    print_${level} "$message"
  done
}
