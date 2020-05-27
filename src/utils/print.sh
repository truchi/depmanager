# shellcheck shell=bash

print.separator() {
  $QUIET && return
  echo "${MAGENTA}~~~~~~~~~~~~~~~~~~~~~${NO_COLOR}"
}

print.date() {
  $QUIET && return
  echo "${MAGENTA}[$(date +"%Y-%m-%d %H:%M:%S")]${NO_COLOR}"
}

print.error() {
  echo "$(print.date) ${RED}${BOLD}✗${NO_COLOR} $*"
}

print.warning() {
  $QUIET && return
  echo "$(print.date) ${YELLOW}${BOLD}!${NO_COLOR} $*"
}

print.success() {
  $QUIET && return
  echo "$(print.date) ${GREEN}${BOLD}✔${NO_COLOR} $*"
}

print.info() {
  $QUIET && return
  echo "$(print.date) ${BLUE}${BOLD}i${NO_COLOR} $*"
}

print.custom() {
  $QUIET && return
  echo "$(print.date) $*"
}

print.confirm() {
  local msg="${BOLD}$1${NO_COLOR} (${BOLD}${YELLOW}Y${NO_COLOR})"
  local auto_answer="$2"

  if helpers.is_set "$auto_answer"; then
    print.fake.input "$msg" "${BOLD}${YELLOW}$auto_answer${NO_COLOR}"
    [[ "$auto_answer" == "yes" ]]
    return
  fi

  if $YES; then
    print.fake.input "$msg" "${BOLD}${YELLOW}yes${NO_COLOR}"
    true
    return
  fi

  # Prompt confirmation message
  local reply
  reply=$(print.input 1 "$msg")

  # Carriage return if user did not press enter
  [[ ! "$reply" =~ ^$ ]] && echo

  # Accepts <Enter>, Y or y
  local confirmed=false
  local answer="no"
  if [[ "$reply" =~ ^[Yy]$ || "$reply" =~ ^$ ]]; then
    confirmed=true
    answer="yes"
  fi

  # Redraw with answer
  print.clear.line
  print.fake.input "$msg" "${BOLD}${YELLOW}$answer${NO_COLOR}"

  $confirmed
}

# MUST NOT be called when $QUIET or ! $IN_TERMINAL
print.input() {
  local n="$1"
  local message="$2"

  # Prompt input
  if ((n == 0)); then
    read -p "$(print.fake.input "$message")" -r
  else
    read -p "$(print.fake.input "$message")" -n "$n" -r
  fi

  echo "$REPLY"
}

print.fake.input() {
  print.custom "${YELLOW}${BOLD}?${NO_COLOR} $1 $2"
}

print.clear.line() {
  $IN_TERMINAL || return
  tput cuu1
  tput el
}

print.version() {
  echo "${YELLOW}v0.0.1${NO_COLOR}"
}

print.summary() {
  echo "${BOLD}${GREEN}depmanager${NO_COLOR} $(print.version)
${MAGENTA}https://github.com/truchi/depmanager${NO_COLOR}"
}

print.help() {
  echo "${BOLD}${BLUE}Usage:${NO_COLOR}
  ${BOLD}${GREEN}$DEPMANAGER_CMD${NO_COLOR} [-h|--version]
  ${BOLD}${GREEN}$DEPMANAGER_CMD${NO_COLOR} [-v|--help]
  ${BOLD}${GREEN}$DEPMANAGER_CMD${NO_COLOR} <cmd> [options|flags]

${BOLD}${BLUE}Description:${NO_COLOR}
  ${WHITE}Manages your packages.

  List packages you depend on in CSV files.
  Export \$DEPMANAGER_DIR environment variable (defaults to \$HOME/.config/depmanager).${NO_COLOR}

${BOLD}${BLUE}Commands:${NO_COLOR}
  I${WHITE},${NO_COLOR} interactive                  ${WHITE}Runs in interactive mode${NO_COLOR}
  s${WHITE},${NO_COLOR} status                       ${WHITE}Produces a report with regard to the CSV files${NO_COLOR}
  i${WHITE},${NO_COLOR} install                      ${WHITE}Installs packages in the CSV files${NO_COLOR}
  u${WHITE},${NO_COLOR} update                       ${WHITE}Updates packages in the CSV files${NO_COLOR}

${BOLD}${BLUE}Options:${NO_COLOR}
  -a${WHITE},${NO_COLOR} --apt    <path|url|ignore>  ${WHITE}Blah${NO_COLOR}
  -y${WHITE},${NO_COLOR} --yum    <path|url|ignore>  ${WHITE}Blah${NO_COLOR}
  -p${WHITE},${NO_COLOR} --pacman <path|url|ignore>  ${WHITE}Blah${NO_COLOR}
  -n${WHITE},${NO_COLOR} --npm    <path|url|ignore>  ${WHITE}Blah${NO_COLOR}
  -r${WHITE},${NO_COLOR} --rust   <path|url|ignore>  ${WHITE}Blah${NO_COLOR}

${BOLD}${BLUE}Flags:${NO_COLOR}
  -Q${WHITE},${NO_COLOR} --quiet                     ${WHITE}Blah${NO_COLOR}
  -Y${WHITE},${NO_COLOR} --yes                       ${WHITE}Blah${NO_COLOR}
  -S${WHITE},${NO_COLOR} --simulate                  ${WHITE}Blah${NO_COLOR}

${BOLD}${BLUE}Links:${NO_COLOR}
  ${WHITE}- Repository${NO_COLOR}                    ${MAGENTA}https://github.com/truchi/depmanager${NO_COLOR}
  ${WHITE}- Website${NO_COLOR}                       ${MAGENTA}https://github.com/truchi/depmanager${NO_COLOR}
  ${WHITE}- Documentation${NO_COLOR}                 ${MAGENTA}https://github.com/truchi/depmanager${NO_COLOR}
"
}

print.system_info() {
  local dir
  helpers.is_set "$DEPMANAGER_DIR" && dir="\$DEPMANAGER_DIR" || dir="default"
  dir=("${BOLD}Depmanager directory${NO_COLOR}" "${BLUE}$(core.csv.path dir)${NO_COLOR}" "($dir)")

  if helpers.is_set "$SYSTEM_MANAGER"; then
    local version
    local levels=("info" "info")
    local messages=("${dir[@]}")
    version=$(core.manager.version "$SYSTEM_MANAGER")
    messages+=("${BOLD}System's manager${NO_COLOR}" "${BLUE}$SYSTEM_MANAGER${NO_COLOR}" "($version)")

    table.print "" 3 levels[@] messages[@]
  else
    print.info "${dir[@]}"
    print.warning "${BOLD}Your system's manager is not supported${NO_COLOR}"
  fi
}

print.csvs_info() {
  local i=0
  local levels=()
  local messages=()
  for manager in "${MANAGERS[@]}"; do
    # Ignore system manager which are not detected on user's system
    if core.manager.is_system "$manager"; then
      core.manager.exists "$manager" || continue
    fi

    messages+=("${BOLD}$manager${NO_COLOR}")
    if   core.manager.is_ignored "$manager"; then messages+=("${BLUE}ignored${NO_COLOR}")
    elif core.csv.exists         "$manager"; then messages+=("${GREEN}$(core.csv.path  "$manager")${NO_COLOR}")
    else                                          messages+=("${YELLOW}$(core.csv.path "$manager")${NO_COLOR}")
    fi

    if   core.manager.is_ignored "$manager"; then  levels+=("info")
    elif core.csv.exists         "$manager"; then  levels+=("success")
    else                                           levels+=("warning")
    fi

    i=$((i + 1))
  done

  table.print "" 2 levels[@] messages[@]
}

print.pre_run_confirm() {
  ! $SIMULATE && print.info "${BOLD}${BLUE}Tip:${NO_COLOR} run with --simulate first"

  # Ask for confirmation
  if $SIMULATE; then print.confirm "Simulate $COMMAND?"
  else               print.confirm "Run $COMMAND?"
  fi
}

