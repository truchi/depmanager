# shellcheck shell=bash

print.safe() {
  local message="$1"
  local respect_quiet="$2"
  local output="$3"

  # respect_quiet defaults to true, otherwise is false
  string.is_empty "$respect_quiet" && respect_quiet=true
  [[ "$respect_quiet" == true ]]   || respect_quiet=false

  $respect_quiet && $QUIET && return

  # output defaults to 1 (stdout), otherwise is 2 (stderr)
  string.is_empty "$output" && output=1
  [[ "$output" == 1 ]]      || output=2

  # Strip sequences if output is a file
  [[ "$output" == "1" ]] && [[ -f /dev/stdout ]] && message=$(string.strip_sequences "$message")
  [[ "$output" == "2" ]] && [[ -f /dev/stderr ]] && message=$(string.strip_sequences "$message")

  # Echo to output
  if [[ "$output" == "1" ]]; then echo "$message"
  else                            echo "$message" >&2
  fi
}

print.custom() {
  print.safe "${MAGENTA}[$(date +"%Y-%m-%d %H:%M:%S")]${NO_COLOR} $1" "$2" "$3"
}

print.separator() {
  print.safe "${MAGENTA}~~~~~~~~~~~~~~~~~~~~~${NO_COLOR}"
}

print.error() {
  print.custom "${RED}${BOLD}✗${NO_COLOR} $1" false "$2"
}

print.warning() {
  print.custom "${YELLOW}${BOLD}!${NO_COLOR} $*"
}

print.success() {
  print.custom "${GREEN}${BOLD}✔${NO_COLOR} $*"
}

print.info() {
  print.custom "${BLUE}${BOLD}i${NO_COLOR} $*"
}

print.question() {
  print.custom "${YELLOW}${BOLD}?${NO_COLOR} $*"
}

print.input() {
  local n="$1"
  local message="$2"

  # Prompt input
  echo -n "$(print.question "$message ")"
  if ((n == 0)); then
    read -p "" -r
  else
    read -p "" -n "$n" -r

    # Carriage return if user did not press enter
    (( $(string.length "$REPLY") == "$n" )) && echo
  fi
}

print.choice() {
  local n="$1"
  local message="$2"
  local options=("${!3}")
  local no_valid_answers="$4"
  local auto_answer="$5"
  local options_str=""
  local letters=()
  local defaults=()

  # Parse options
  local options_count="${#options[@]}"
  for i in "${!options[@]}"; do
    local option="${options[$i]}"
    local letter
    local rest
    letter=$(string.slice "$option" 0 1)
    rest=$(string.slice "$option" 1)

    letters+=("$letter")
    options_str+="${BOLD}${YELLOW}$letter${NO_COLOR}$rest"
    ((i < $((options_count - 1)))) && options_str+=", "
    string.is_uppercase "$letter" && defaults+=(true) || defaults+=(false)
  done

  message="$message ($options_str)"

  # Prompt
  if string.is_empty "$auto_answer"; then
    print.input "$n" "$message"
  else
    REPLY="$auto_answer"
  fi

  local answer
  local answer_arr=()
  if string.is_empty "$REPLY"; then
    # When reply is empty, answer is made of default options
    for i in "${!defaults[@]}"; do
      ${defaults[$i]} && answer_arr+=("${options[$i]}")
    done
  else
    # Look for option letters in reply
    for i in "${!options[@]}"; do
      local letter="${letters[$i]}"
      local letter_lower
      letter_lower=$(string.lowercase "${letters[$i]}")

      if string.contains "$REPLY" "$letter" || string.contains "$REPLY" "$letter_lower"; then
        answer_arr+=("${options[$i]}")
      fi
    done
  fi

  # Concat answers, and default to $no_valid_answers
  answer=$(string.lowercase "${answer_arr[*]}")
  string.is_empty "$answer" && answer="$no_valid_answers"

  # Redraw with answer
  string.is_empty "$auto_answer" && print.clear.line
  print.question "$message ${BOLD}${YELLOW}$answer${NO_COLOR}"

  # "Return"
  REPLY="$answer"
}

print.confirm() {
  local message="$1"
  local auto_answer="$2"
  local options=("Yes")

  string.is_empty "$auto_answer" && $YES && auto_answer="y"

  print.choice 1 "$message" options[@] "no" "$auto_answer"
  [[ "$REPLY" == "yes" ]]
}

print.clear.line() {
  $IN_TERMINAL || return
  $QUIET       && return
  tput cuu1
  tput el
}

print.version() {
  echo "${YELLOW}${VERSION}${NO_COLOR}"
}

print.summary() {
  echo "${BOLD}${GREEN}depmanager${NO_COLOR} $(print.version)
${CYAN}https://github.com/truchi/depmanager${NO_COLOR}"
}

print.help() {
  local cmd
  cmd=$(basename "$0")

  echo "${BOLD}${BLUE}Usage:${NO_COLOR}
  ${BOLD}${GREEN}$cmd${NO_COLOR} [-h|--version]
  ${BOLD}${GREEN}$cmd${NO_COLOR} [-v|--help]
  ${BOLD}${GREEN}$cmd${NO_COLOR} <cmd> [options] [flags]

${BOLD}${BLUE}Description:${NO_COLOR}
  ${WHITE}Manages your packages. (apt, npm)
  Reads existing non-empty ${CYAN}<manager>.csv${NO_COLOR}${WHITE} files in \$DEPMANAGER_DIR (defaults to ${CYAN}\$HOME/.config/depmanager${NO_COLOR}${WHITE}).${NO_COLOR}

${BOLD}${BLUE}Commands:${NO_COLOR}
  I${WHITE},${NO_COLOR} interactive               ${WHITE}Runs in interactive mode: asks for CSVs path/url, command and flags.${NO_COLOR}
  s${WHITE},${NO_COLOR} status                    ${WHITE}Shows packages local and remote versions.${NO_COLOR}
  i${WHITE},${NO_COLOR} install                   ${WHITE}Installs or updates packages.${NO_COLOR}
  u${WHITE},${NO_COLOR} update                    ${WHITE}Updates installed packages.${NO_COLOR}

${BOLD}${BLUE}Options:${NO_COLOR}
  -a${WHITE},${NO_COLOR} --apt <path|url|ignore>  ${WHITE}Path/Url of the apt CSV file. \`ignore\` to ignore apt.${NO_COLOR}
  -n${WHITE},${NO_COLOR} --npm <path|url|ignore>  ${WHITE}Path/Url of the npm CSV file. \`ignore\` to ignore npm.${NO_COLOR}

${BOLD}${BLUE}Flags:${NO_COLOR}
  -Q${WHITE},${NO_COLOR} --quiet                  ${WHITE}Prints errors only. Implies \`--yes\`.${NO_COLOR}
  -Y${WHITE},${NO_COLOR} --yes                    ${WHITE}Answers \`yes\` to all prompts. Forced when stdout is not a terminal.${NO_COLOR}
  -S${WHITE},${NO_COLOR} --simulate               ${WHITE}Answers \`no\` to installation prompts. Implies NOT \`--quiet\`.${NO_COLOR}

${BOLD}${BLUE}Links:${NO_COLOR}
  ${WHITE}- Repository${NO_COLOR}                 ${CYAN}https://github.com/truchi/depmanager${NO_COLOR}
"
}

print.system_info() {
  local dir
  helpers.is_set "$DEPMANAGER_DIR" && dir="\$DEPMANAGER_DIR" || dir="default"
  dir=("${BOLD}Depmanager directory${NO_COLOR}" "${BLUE}$(core.csv.path dir)${NO_COLOR}" "($dir)")

  if helpers.is_set "$SYSTEM_MANAGER"; then
    local version
    core.manager.version "$SYSTEM_MANAGER" > /dev/null
    version=$(core.manager.version "$SYSTEM_MANAGER")
    local messages=("${dir[@]}")
    messages+=("${BOLD}System's manager${NO_COLOR}" "${BLUE}$SYSTEM_MANAGER${NO_COLOR}" "($version)")
    local levels=("info" "info")

    table.print "" 3 levels[@] messages[@]
  else
    print.info "${dir[@]}"
    print.warning "${BOLD}Your system's manager is not supported${NO_COLOR}"
  fi
}

print.csvs_info() {
  local managers=()
  helpers.is_set "$SYSTEM_MANAGER" && managers+=("$SYSTEM_MANAGER")
  managers+=("${NON_SYSTEM_MANAGERS[@]}")

  local levels=()
  local messages=()
  for manager in "${managers[@]}"; do
    messages+=("${BOLD}$manager${NO_COLOR}")

    if core.manager.is_ignored "$manager"; then
      messages+=("${BLUE}ignored${NO_COLOR}")
      messages+=("")
      levels+=("info")
      continue
    fi

    if ! core.csv.exists "$manager"; then
      messages+=("${YELLOW}$(core.csv.path "$manager")${NO_COLOR}")
      messages+=("(not found)")
      levels+=("warning")
      continue
    fi

    if core.csv.is_empty "$manager"; then
      messages+=("${YELLOW}$(core.csv.path "$manager")${NO_COLOR}")
      messages+=("(empty)")
      levels+=("warning")
      continue
    fi

    messages+=("${GREEN}$(core.csv.path "$manager")${NO_COLOR}")
    messages+=("")
    levels+=("success")
  done

  # FIXME first column is larger than expected...
  table.print "" 3 levels[@] messages[@]
}

print.pre_run_confirm() {
  ! $SIMULATE && print.info "${BOLD}${BLUE}Tip:${NO_COLOR} run with --simulate/-S first"

  local cmd="$COMMAND"
  $QUIET    && cmd+=" --quiet"
  $YES      && cmd+=" --yes"
  $SIMULATE && cmd+=" --simulate"

  # Ask for confirmation
  print.confirm "${BOLD}Run ${YELLOW}$cmd${NO_COLOR}${BOLD}?${NO_COLOR}"
}

