#!/usr/bin/env bash
#
# depmanager v0.0.1
# https://github.com/truchi/depmanager
#
# Usage:
#   depmanager [-h|--version]
#   depmanager [-v|--help]
#   depmanager <cmd> [options] [flags]
#
# Description:
#   Manages your packages. (apt, npm)
#   Reads existing non-empty <manager>.csv files in $DEPMANAGER_DIR (defaults to $HOME/.config/depmanager).
#
# Commands:
#   I, interactive               Runs in interactive mode: asks for CSVs path/url, command and flags.
#   s, status                    Shows packages local and remote versions.
#   i, install                   Installs or updates packages.
#   u, update                    Updates installed packages.
#
# Options:
#   -a, --apt <path|url|ignore>  Path/Url of the apt CSV file. `ignore` to ignore apt.
#   -n, --npm <path|url|ignore>  Path/Url of the npm CSV file. `ignore` to ignore npm.
#
# Flags:
#   -Q, --quiet                  Prints errors only. Implies `--yes`.
#   -Y, --yes                    Answers `yes` to all prompts. Forced when stdout is not a terminal.
#   -S, --simulate               Answers `no` to installation prompts. Implies NOT `--quiet`.
#
# Links:
#   - Repository                 https://github.com/truchi/depmanager

SYSTEM_MANAGERS=(apt)
NON_SYSTEM_MANAGERS=(npm rust)
MANAGERS=("${SYSTEM_MANAGERS[@]}" "${NON_SYSTEM_MANAGERS[@]}")

SYSTEM_MANAGER=
COMMAND=
QUIET=false
YES=false
SIMULATE=false

declare -A __cache
declare -A async_versions
declare -A CSVS
declare -A DEFAULTS
DEFAULTS[dir]="$HOME/.config/depmanager"
for manager in "${MANAGERS[@]}"; do
  DEFAULTS[$manager]="$manager.csv"
done

PACKAGE_NONE="<NONE>"
DEPMANAGER_TMP_DIR="/tmp/depmanager"
mkdir -p "$DEPMANAGER_TMP_DIR"

IN_TERMINAL=false
[ -t 1 ] && IN_TERMINAL=true
NO_COLOR=$(tput sgr0)
BOLD=$(tput bold)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)

SYSTEM_MANAGERS=(apt)
NON_SYSTEM_MANAGERS=(npm rust)
MANAGERS=("${SYSTEM_MANAGERS[@]}" "${NON_SYSTEM_MANAGERS[@]}")

SYSTEM_MANAGER=
COMMAND=
QUIET=false
YES=false
SIMULATE=false

declare -A __cache
declare -A async_versions
declare -A CSVS
declare -A DEFAULTS
DEFAULTS[dir]="$HOME/.config/depmanager"
for manager in "${MANAGERS[@]}"; do
  DEFAULTS[$manager]="$manager.csv"
done

PACKAGE_NONE="<NONE>"
DEPMANAGER_TMP_DIR="/tmp/depmanager"
mkdir -p "$DEPMANAGER_TMP_DIR"

IN_TERMINAL=false
[ -t 1 ] && IN_TERMINAL=true
NO_COLOR=$(tput sgr0)
BOLD=$(tput bold)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)

#
# Returns true is $1 is set, false otherwise
#
helpers.is_set() {
  [[ -n "$1" ]]
}

#
# Returns true if file $1 exists, false otherwise
#
helpers.file_exists() {
  [[ -f "$1" ]]
}

#
# Returns true if url $1 exists, false otherwise
#
helpers.url_exists() {
  wget -q --spider "$1"
}

#
# Returns true if $1 is found on the system, false otherwise
#
helpers.command_exists() {
  command -v "$1" >/dev/null 2>&1
}

#
# Returns true is executed in a subshell, false otherwise
#
helpers.is_subshell() {
  [ "$$" -ne "$BASHPID" ]
}
#
# Removes blanks and duplicates from CSV (stdin)
#
helpers.sanitize_csv() {
  local lines=""
  local packages=()

  while read -ra line; do
    # Remove whitespaces
    line=$(sed 's/[[:space:]]*//g' <<< "${line[*]}")

    # Ignore if empty
    [[ $(string.length "$line") == 0 ]] && continue

    # Read first column
    local package
    IFS=, read -ra package <<< "$line"
    [[ $(string.length "$package") == 0 ]] && continue

    # Ignore if already there
    array.includes "$package" packages[@] && continue
    packages+=("$package")

    # Remove trailing comma
    line=$(sed 's/,$//g' <<< "$line")

    lines+="$line
"
  done

  # Remove trailing newline
  lines=$(sed 's/\s$//g' <<< "$lines")

  echo "$lines"
}

#
# Caches the return code and echoed string of a function
# DO NOT call from subshell: memory would not be written, script will die
#
cache() {
  local args=("$@")
  local cache_key="$1"
  local read_cache="$2"
  local write_cache="$3"
  local cmd="$4"

  local string
  local code

  # Read from cache or execute
  if $read_cache && cache.has "$cache_key"; then
    string=$(cache.get_string "$cache_key")
    code=$(cache.get_code "$cache_key")
  else
    args=("${args[@]:4}")

    string=$($cmd "${args[@]}")
    code="$?"

    # Write to cache
    if $write_cache; then
      # NOTE cannot write cache in a subshell
      if helpers.is_subshell; then
        # Terminating whole script
        echo "HELPERS.CACHE CANNOT WRITE IN A SUBSHELL (key: $cache_key, cmd: $cmd)"
        kill $$
        exit
      fi

      cache.set "$cache_key" "$string" "$code"
    fi
  fi

  # Echo string and return code
  string.is_empty "$string" || echo "$string"
  return $code
}

#
# Returns true if cache has data for in key $1, false otherwise
#
cache.has() {
  helpers.is_set "${__cache[$1]}"
}

#
# Gets cached string for key $1
#
cache.get_string() {
  echo "${__cache[__${1}__string]}"
}

#
# Gets cached code for key $1
#
cache.get_code() {
  echo "${__cache[__${1}__code]}"
}

#
# Sets cache string $2 and code $3 in key $1
#
cache.set() {
  __cache[$1]=true
  __cache[__${1}__string]="$2"
  __cache[__${1}__code]="$3"
}

#
# Creates fifo $1
#
cache.async.init() {
  local fifo="$1"

  # Creates new fifo
  [ -p "$fifo" ] && rm "$fifo"
  mknod "$fifo" p
}

#
# Write value $3 in fifo $1 for cache key $2
#
cache.async.write() {
  local fifo="$1"
  local key="$2"
  local value="$3"

  echo "$key,$value" > "$fifo"
}

#
# Creates and reads fifo named $1, $2 times, and writes data in cache
# Runs command $3 after read happens, with $... args
#
cache.async.listen() {
  local fifo="$1"
  local count="$2"
  local cmd="$3"
  local args=("$@")
  args=("${args[@]:3}")

  # Infinite loop (the only way to make this work properly?)
  local i=0
  while true; do
    local data
    local array

    # Read fifo
    read -r data
    ! helpers.is_set "$data" && continue

    # Read data and write in cache
    IFS=, read -r -a array <<< "$data"
    cache.set "${array[0]}" "${array[1]}" 0

    string.is_empty "$cmd" || $cmd "${args[@]}"

    i=$((i + 1))
    (( i == count )) && break
  done < "$fifo"
}

string.is_empty() {
  [[ -z "$1" ]]
}

string.raw_length() {
  local str="$1"
  echo ${#str}
}

string.length() {
  local str
  str=$(string.strip_sequences "$1")
  echo ${#str}
}

string.strip_sequences() {
  echo -e "$1" | sed "s/$(echo -e "")[^m]*m//g"
}

string.is_number() {
  local re='^[0-9]+$'
  [[ "$1" =~ $re ]]
}

#
# Returns true if $@ starts with /, false otherwise
#
string.is_absolute() {
  [[ "$1" =~ / ]]
}

#
# Returns true if $@ starts with https?://, false otherwise
#
string.is_url() {
  [[ "$1" =~ https?:// ]]
}

#
# Retuns true if $1 contains $2, false otherwise
#
string.contains() {
  [[ "$1" == *"$2"* ]]
}

#
# Replaces $2 with $3 in $1
#
string.replace() {
  echo "${1//$2/$3}"
}

#
# Returns true if $1 equals $2, false otherwise
#
string.equals() {
  [[ "$1" == "$2" ]]
}

#
# Returns $1 from index $2 with length $3 (optional)
#
string.slice() {
  local string="$1"
  local offset="$2"
  local length="$3"

  ! helpers.is_set "$length" && length=$(string.length "$string")

  echo "${string:$offset:$length}"
}

#
# Returns $1 lowercased
#
string.lowercase() {
  echo "${1,,}"
}

#
# Returns true if $1 is uppercased, false otherwise
#
string.is_uppercase() {
  [[ "$1" == "${1^^}" ]]
}

string.center() {
  local str="$1"
  local width="$2"
  local length
  length=$(string.length "$str")

  if (( width < length )); then
    echo "$str"
  else
    local rest=$((width - length))
    local left_padding=$((rest / 2))
    local right_padding=$((width - left_padding))

    local left
    local right

    left=$(string.pad_right "" $left_padding)
    right=$(string.pad_right "$str" $right_padding)
    echo "$left$right"
  fi
}

string.pad_right() {
  local str="$1"
  local width="$2"
  local length
  length=$(string.length "$str")
  local raw_length
  raw_length=$(string.raw_length "$str")

  printf "%-$((width + raw_length - length))s" "$str"
}

#
# Returns length of array $1
#
array.length() {
  local array=("${!1}")
  echo "${#array[*]}"
}

#
# Returns true if $1 is found in $2, false otherwise
#
array.includes() {
  local needle="$1"
  local array=("${!2}")

  for item in "${array[@]}"; do
    if [[ "$item" == "$needle" ]]; then
      true
      return
    fi
  done

  false
}

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
  echo "${YELLOW}v0.0.1${NO_COLOR}"
}

print.summary() {
  echo "${BOLD}${GREEN}depmanager${NO_COLOR} $(print.version)
${MAGENTA}https://github.com/truchi/depmanager${NO_COLOR}"
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
  Reads existing non-empty ${MAGENTA}<manager>.csv${NO_COLOR}${WHITE} files in \$DEPMANAGER_DIR (defaults to ${MAGENTA}\$HOME/.config/depmanager${NO_COLOR}${WHITE}).${NO_COLOR}

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
  ${WHITE}- Repository${NO_COLOR}                 ${MAGENTA}https://github.com/truchi/depmanager${NO_COLOR}
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
#!/bin/bash

table.print() {
  local pad=2
  local title=$1
  local headers=("${!2}")
  local column_count=$2
  local levels=("${!3}")
  local data=("${!4}")

  local has_title
  local has_headers
  local row_count
  has_title=$(string.is_empty "$title" && echo false || echo true)
  has_headers=$(string.is_number "$column_count" && echo false || echo true)
  $has_headers && column_count=$(array.length headers[@])
  row_count=$(array.length levels[@])

  local total_length
  local column_length=()
  for column_index in $(seq 0 $((column_count - 1))); do
    local column=()
    table.get_column "$column_index" "$column_count" data[@]

    local max_length
    max_length=$(string.length "${headers[$column_index]}")
    for cell in "${column[@]}"; do
      local cell_length
      cell_length=$(string.length "$cell")
      (( cell_length > max_length )) && max_length=$cell_length
    done

    ((max_length == -1)) && max_length=0
    max_length=$((max_length + pad))
    total_length=$((total_length + max_length))
    column_length[$column_index]=$max_length
  done

  $has_title && print.custom "  $(string.center "$title" $total_length)"
  total_length=$((total_length - pad))

  if $has_headers; then
    local header_row=""
    for column_index in $(seq 0 $((column_count - 1))); do
      header=${headers[$column_index]}
      header_row="$header_row$(string.center "$header" "${column_length[$column_index]}")"
    done
    print.custom "  ${header_row[*]}"
  fi

  for row_index in $(seq 0 $((row_count - 1))); do
    local message=""
    local level="${levels[$row_index]}"
    local row=()
    table.get_row "$row_index" "$column_count" data[@]

    for column_index in $(seq 0 $((column_count - 1))); do
      local cell="${row[$column_index]}"
      message="$message$(string.pad_right "$cell" "${column_length[$column_index]}")"
    done

    "print.${level}" "$message"
  done
}

table.get_row() {
  local row_index=$1
  local column_count=$2
  local data=("${!3}")
  local first=$((row_index * column_count))
  local rowi1=$((row_index + 1))
  local last=$((rowi1 * column_count - 1))

  local i=-1
  for cell in "${data[@]}"; do
    i=$((i + 1))

    ((i < first)) && continue
    ((i > last )) && break
    row+=("$cell")
  done
}

table.get_column() {
  local column_index=$1
  local column_count=$2
  local data=("${!3}")

  local i=-1
  for cell in "${data[@]}"; do
    i=$((i + 1))

    if (($((i % column_count)) == column_index)); then
      column+=("$cell")
    else
      continue
    fi
  done
}

SYSTEM_MANAGERS=(apt)
NON_SYSTEM_MANAGERS=(npm rust)
MANAGERS=("${SYSTEM_MANAGERS[@]}" "${NON_SYSTEM_MANAGERS[@]}")

SYSTEM_MANAGER=
COMMAND=
QUIET=false
YES=false
SIMULATE=false

declare -A __cache
declare -A async_versions
declare -A CSVS
declare -A DEFAULTS
DEFAULTS[dir]="$HOME/.config/depmanager"
for manager in "${MANAGERS[@]}"; do
  DEFAULTS[$manager]="$manager.csv"
done

PACKAGE_NONE="<NONE>"
DEPMANAGER_TMP_DIR="/tmp/depmanager"
mkdir -p "$DEPMANAGER_TMP_DIR"

IN_TERMINAL=false
[ -t 1 ] && IN_TERMINAL=true
NO_COLOR=$(tput sgr0)
BOLD=$(tput bold)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)

#
# Sets `DIR` according to (in this precedence order):
# - env variable (relative to home)
# - default path
#
core.dir.resolve() {
  local dir=""

  # If env variable is defined
  if helpers.is_set "$DEPMANAGER_DIR"; then
    # Use user's dir
    dir="$DEPMANAGER_DIR"

    # Relative to home
    ! string.is_absolute "$dir" && dir="$HOME/$dir"
  else
    # Use default dir
    dir="${DEFAULTS[dir]}"
  fi

  CSVS[dir]="$dir"
}

#
# Sets and returns $1 manager's CSV path according to (in this precedence order):
# - cli arg          (relative to current workin directory)
# - default variable (relative to `CSVS[dir]`, see core.dir.resolve)
#
core.csv.path() {
  local manager="$1"
  local file="${CSVS[$1]}"

  # If file is given in args
  if helpers.is_set "$file"; then
    if [[ "$file" != "ignore" ]]; then
      # Expand ~
      file="${file/#\~/$HOME}"

      # Relative to current working dir
      ! string.is_absolute "$file" && ! string.is_url "$file" && file="$(realpath -m "$file")"
    fi
  else
    # Use default file, relative to CSVS[dir]
    file="${CSVS[dir]}/${DEFAULTS[$manager]}"
  fi

  CSVS[$manager]="$file"
  echo "$file"
}

#
# Returns true if $1 manager's CSV exists (file/url), false otherwise
# With cache
#
core.csv.exists() {
  local manager="$1"
  local cache="$2"

  # Do not worry about ignored
  if core.manager.is_ignored "$manager"; then
    true # NOTE or false?
    return
  fi

  local file
  file=$(core.csv.path "$manager")

  local cmd
  string.is_url "$file" && cmd="helpers.url_exists $file" || cmd="helpers.file_exists $file"

  string.is_empty "$cache" && cache=true
  cache "core_csv_exists__$file" "$cache" "$cache" "$cmd"
}

#
# Returns content of $1 manager's CSV
# With cache
#
core.csv.get() {
  local manager="$1"
  local file
  file=$(core.csv.path "$manager")

  cache "core_csv_get__$file" true true "__core.csv.get" "$file"
}

#
# Returns content of $1 manager's CSV
# For cache
#
__core.csv.get() {
  local file="$1"

  if string.is_url "$file"; then
    wget "$file" | helpers.sanitize_csv
  else
    helpers.sanitize_csv < "$file"
  fi
}

#
# Retuns true if $1 manager's CSV is empty, false otherwise
#
core.csv.length() {
  local manager="$1"

  if core.csv.is_empty "$manager"; then
    echo 0
    return
  fi

  local csv
  csv=$(core.csv.get "$manager")

  wc -l <<< "$csv"
}

#
# Retuns true if $1 manager's CSV is empty, false otherwise
#
core.csv.is_empty() {
  local manager="$1"

  core.csv.get "$manager" > /dev/null
  string.is_empty "$(core.csv.get "$manager")"
}

#
# Sets `SYSTEM_MANAGER` to the first found system manager
#
core_manager_system_ran=false
core.manager.system() {
  # Already detected?
  $core_manager_system_ran && return

  # Try all system managers
  for manager in "${SYSTEM_MANAGERS[@]}"; do
    if core.manager.exists "$manager"; then
      SYSTEM_MANAGER="$manager"
      return
    fi
  done

  core_manager_system_ran=true
}

#
# Returns true if $1 is in `SYSTEM_MANAGERS`, false otherwise
#
core.manager.is_system() {
  array.includes "$1" SYSTEM_MANAGERS[@]
}

#
# Returns true if manager $1 is by-passed
#
core.manager.is_ignored() {
  [[ $(core.csv.path "$1") == "ignore" ]]
}

#
# Returns true if manager $1 is found on the system, false otherwise
# With cache (system managers only)
#
core.manager.exists() {
  local manager="$1"
  local write_cache=false

  core.manager.is_system "$manager" && write_cache=true
  cache "core_manager_exists__$manager" true "$write_cache" "managers.${manager}.exists"
}

#
# Returns manager $1 version
# With cache
#
core.manager.version() {
  local manager="$1"
  local write_cache="$2"

  string.is_empty "$write_cache" && write_cache=true
  cache "core_manager_version__$manager" true "$write_cache" "managers.${manager}.version"
}

#
# Writes cache for "__managers.${1}.list.local" (if exists)
#
core.manager.cache_list() {
  local manager="$1"

  if helpers.command_exists "__managers.${manager}.list.local"; then
    cache "managers_${manager}_list_local" true true "__managers.${manager}.list.local" > /dev/null
  fi
}

#
# Asynchronously writes the manager $1 version and packages versions (local/remote) in cache
# Runs command $2 as callback for async version calls, with $... args
#
core.manager.async.versions() {
  local manager="$1"
  local cmd="$2"
  local args=("$@")
  args=("${args[@]:2}")

  local fifo="$DEPMANAGER_TMP_DIR/fifo__${manager}"

  # Init async cache
  cache.async.init "$fifo"

  # Get manager version asynchronously
  (cache.async.write "$fifo" "core_manager_version__$manager" "$(core.manager.version "$manager" false)") &

  # Write CSV cache
  core.csv.get "$manager" > /dev/null

  # Cache list
  core.manager.cache_list "$manager"

  # For all manager's packages
  local i=0
  while IFS=, read -ra line; do
    local package=${line[0]}

    # Asynchronously write versions in async cache
    (cache.async.write "$fifo" \
        "core_package_version_local__${manager}__${package}" \
        "$(core.package.version.local "$manager" "$package" false)") &
    (cache.async.write "$fifo" \
        "core_package_version_remote__${manager}__${package}" \
        "$(core.package.version.remote "$manager" "$package" false)") &

    i=$((i + 1))
  done < <(core.csv.get "$manager")

  # Listen to async cache fifo
  cache.async.listen "$fifo" $((i * 2 + 1)) "$cmd" "${args[@]}"
}

#
# Returns true if package $2 of manager $1 exists, false otherwise
#
core.package.exists() {
  local manager="$1"
  local package="$2"
  local version

  # Write cache
  core.package.version.remote "$manager" "$package" > /dev/null

  # Has version?
  [[ $(core.package.version.remote "$manager" "$package") != "$PACKAGE_NONE" ]]
}

#
# Returns true if package $2 of manager $1 is installed, false otherwise
#
core.package.is_installed() {
  local manager="$1"
  local package="$2"
  local version

  # Write cache
  core.package.version.local "$manager" "$package" > /dev/null

  # Has version?
  [[ $(core.package.version.local "$manager" "$package") != "$PACKAGE_NONE" ]]
}

#
# Returns true if package $2 of manager $1 exists, is installed and is up-to-date, false otherwise
#
core.package.is_uptodate() {
  local manager="$1"
  local package="$2"
  local local_version
  local remote_version

  # Not uptodate if doesn't exists
  if ! core.package.exists "$manager" "$package"; then
    false
    return
  fi

  # Not uptodate if not installed
  if ! core.package.is_installed "$manager" "$package"; then
    false
    return
  fi

  # Get versions
  local_version=$(core.package.version.local "$manager" "$package")
  remote_version=$(core.package.version.remote "$manager" "$package")

  # Compare versions
  [[ "$local_version" == "$remote_version" ]]
}

#
# Returns the local version of package $2 of manager $1
# With cache
#
core.package.version.local() {
  __core.package.version "$1" "$2" "$3" "local"
}

#
# Returns the remote version of package $2 of manager $1
# With cache
#
core.package.version.remote() {
  __core.package.version "$1" "$2" "$3" "remote"
}

#
# Returns the version (type $4) of package $2 of manager $1
# With cache
#
__core.package.version() {
  local manager="$1"
  local package="$2"
  local write_cache="$3"
  local version_type="$4"
  local cmd="managers.${manager}.package.version.${version_type}"

  string.is_empty "$write_cache" && write_cache=true
  cache "core_package_version_${version_type}__${manager}__${package}" true "$write_cache" "$cmd" "$package"
}

#
# Returns true if apt is found on the system, false otherwise
#
managers.apt.exists() {
  helpers.command_exists apt && helpers.command_exists apt-cache && helpers.command_exists dpkg
}

#
# Returns apt version
#
managers.apt.version() {
  apt --version
}

#
# Returns the local version of package $1
#
managers.apt.package.version.local() {
  local dpkg_list
  dpkg_list=$(dpkg -l "$1" 2> /dev/null)

  # If dpkg errors, package is not installed
  if [[ $? != 0 ]]; then
    echo "$PACKAGE_NONE"
    return
  fi

  # Get relevant line
  dpkg_list=$(sed '6q;d' <<< "$dpkg_list")

  # If status is not "i", package is not installed
  if [[ $(string.slice "$dpkg_list" 1 1) != "i" ]]; then
    echo "$PACKAGE_NONE"
    return
  fi

  # Extract version
  sed 's/\S*\s*\S*\s*\(\S*\).*/\1/' <<< "$dpkg_list"
}

#
# Returns the remote version of package $1
#
managers.apt.package.version.remote() {
  local policy
  policy=$(apt-cache policy "$1")

  # If apt returns nothing, package is not installed
  if string.is_empty "$policy"; then
    echo "$PACKAGE_NONE"
    return
  fi

  # Extract version
  echo "$policy" | sed '3q;d' | sed 's/  Candidate: \(.*\).*/\1/'
}

#
# Returns the installation command for package $1
#
managers.apt.package.install_command() {
  local package="$1"
  local quiet="$2"

  cmd=("sudo" "apt" "install" "$package" "--yes")
  $quiet && cmd+=("--quiet")
}

#
# Returns true if npm is found on the system, false otherwise
#
managers.npm.exists() {
  helpers.command_exists npm
}

#
# Returns npm version
#
managers.npm.version() {
  npm --version
}

__managers.npm.list.local() {
  npm list --global --depth 0 | grep "── "
}

#
# Returns the local version of package $1
#
managers.npm.package.version.local() {
  local list
  list=$(cache "managers_npm_list_local" true | grep "── $1@")

  # If npm returns "(empty)", package is not installed
  if [[ "$list" == "" ]]; then
    echo "$PACKAGE_NONE"
    return
  fi

  # Extract version
  sed 's/.*@//' <<< "$list"
}

#
# Returns the remote version of package $1
#
managers.npm.package.version.remote() {
  local version
  version=$(npm view "$1" version 2> /dev/null)

  # If npm errors, package is not installed
  if [[ $? != 0 ]]; then
    echo "$PACKAGE_NONE"
    return
  fi

  # Return version
  echo "$version"
}

#
# Returns the installation command for package $1
#
managers.npm.package.install_command() {
  local package="$1"
  local quiet="$2"

  cmd=("npm" "install" "$package" "--global" "--no-progress")
  $quiet && cmd+=("--quiet")
}

command.interactive() {
  local managers
  local length
  managers=("$SYSTEM_MANAGER" "${NON_SYSTEM_MANAGERS[@]}")
  length=$(array.length managers[@])

  # Ask for CSVs
  for i in $(seq 0 $((length - 1))); do
    local manager="${managers[$i]}"

    [[ $i != 0 ]] && print.separator
    print.info "${BOLD}$manager${NO_COLOR}"

    local path
    local is_ignored
    local exists
    local default_path
    local default_color
    path=$(core.csv.path "$manager")
    is_ignored=$(core.manager.is_ignored "$manager" && echo true || echo false)
    exists=$(core.csv.exists "$manager" false && echo true || echo false)

    # Default value for prompt is the path if exists, ignore
    default_path="ignore"
    default_color="${BLUE}"
    if ! $is_ignored && $exists; then
      default_color="$GREEN"
      default_path="$path"
    fi

    local first=true
    while $first || (! $is_ignored && ! $exists); do
      local message
      local new_path

      # On the first run, print error if supplied path does not exists
      if $first && ! $is_ignored && ! $exists; then
        print.warning "${RED}$path${NO_COLOR} not found"
      fi

      # Ask for path
      message="CSV (${default_color}$default_path${NO_COLOR}):"
      print.input 0 "$message"
      new_path="$REPLY"
      [[ "$new_path" =~ ^$ ]] && new_path="$default_path"
      CSVS[$manager]="$new_path"

      # Update
      path=$(core.csv.path "$manager")
      is_ignored=$(core.manager.is_ignored "$manager" && echo true || echo false)
      exists=$(core.csv.exists "$manager" false && echo true || echo false)

      # Redraw
      print.clear.line
      if $is_ignored; then
        print.info "$message ${BLUE}$path${NO_COLOR}"
      elif $exists; then
        print.success "$message ${GREEN}$path${NO_COLOR}"
      else
        print.warning "$message ${RED}$path${NO_COLOR}"
      fi

      first=false
    done
  done

  print.separator

  # Ask for command
  local options=("Status" "install" "update")
  print.choice 1 "${BOLD}Command?${NO_COLOR}" options[@]
  COMMAND="$REPLY"

  [[ $COMMAND == "status" ]] && return

  # Ask for flags
  local options=()
  $_QUIET    && options+=("Quiet")    || options+=("quiet")
  $_YES      && options+=("Yes")      || options+=("yes")
  $_SIMULATE && options+=("Simulate") || options+=("simulate")

  print.choice 3 "${BOLD}Flags?${NO_COLOR}" options[@]
  string.contains "$REPLY" "quiet"    && QUIET=true
  string.contains "$REPLY" "yes"      && YES=true
  string.contains "$REPLY" "simulate" && SIMULATE=true
}

#
# Prints status table
# Redraw $2 lines
# Throttles 1 second
#
command.status.update_table() {
  # Throttle 1s
  [[ -z $last_update ]] && last_update=0
  local now
  now=$(date +%s)
  ((now - last_update < 1)) && return

  local manager=$1
  local remove=$2
  local headers=()
  local levels=()
  local messages=()

  # Make array for table
  local i=1
  while IFS=, read -ra line; do
    local package=${line[0]}

    # We try to read the cache for version
    local local_version_done=false
    local remote_version_done=false
    local both_versions_done=false

    cache.has "core_package_version_local__${manager}__${package}"  && local_version_done=true
    cache.has "core_package_version_remote__${manager}__${package}" && remote_version_done=true
    $local_version_done && $remote_version_done                     && both_versions_done=true

    # Read cache if set
    local local_version="..."
    local remote_version="..."
    $local_version_done  && local_version=$(core.package.version.local   "$manager" "$package")
    $remote_version_done && remote_version=$(core.package.version.remote "$manager" "$package")

    # Check the statuses of package
    local is_installed=false
    local exists=false
    local is_uptodate=false

    $local_version_done  && core.package.is_installed "$manager" "$package" && is_installed=true
    $remote_version_done && core.package.exists       "$manager" "$package" && exists=true
    $both_versions_done  && core.package.is_uptodate  "$manager" "$package" && is_uptodate=true

    # Prepare printing vars
    local local_version_color=""
    local remote_version_color=""
    local level="info"

    $local_version_done  && ! $is_installed && local_version_color="$RED"  && level="error"
    $remote_version_done && ! $exists       && remote_version_color="$RED" && level="error"

    $both_versions_done                                    && local_version_color="$RED"
    $both_versions_done   && $is_installed                 && local_version_color="$YELLOW"
    $both_versions_done   && $is_installed && $is_uptodate && local_version_color="$GREEN"
    $both_versions_done                                    && level="error"
    $both_versions_done   && $is_installed                 && level="warning"
    $both_versions_done   && $is_installed && $is_uptodate && level="success"

    # Table row
    messages+=("${BOLD}$package${NO_COLOR}")
    messages+=("${local_version_color}$local_version${NO_COLOR}")
    messages+=("${remote_version_color}$remote_version${NO_COLOR}")
    levels+=("$level")

    i=$((i + 1))
  done < <(core.csv.get "$manager")

  # Same, need cache
  local manager_version="..."
  cache.has "core_manager_version__$manager" && manager_version=$(core.manager.version "$manager")

  # Title and headers
  local title="${BLUE}${BOLD}$manager${NO_COLOR} ($manager_version)"
  headers+=("${BLUE}${BOLD}Package${NO_COLOR}")
  headers+=("${BLUE}${BOLD}Local${NO_COLOR}")
  headers+=("${BLUE}${BOLD}Remote${NO_COLOR}")

  # Clear screen
  # (status should never be quiet, screen should be drawn only once outside a terminal)
  if ! $QUIET && $IN_TERMINAL; then
    for i in $(seq 1 "$remove"); do
      tput cuu1
    done
  fi

  # Print!
  table.print "$title" headers[@] levels[@] messages[@]
  last_update=$(date +%s)
}

command.status() {
  local manager=$1
  local length
  length=$(core.csv.length "$manager")
  length=$((length + 2))

  # If in terminal
  if $IN_TERMINAL; then
    last_update=0
    command.status.update_table "$manager" 0
    core.manager.async.versions "$manager" "command.status.update_table" "$manager" "$length"
    last_update=0
    command.status.update_table "$manager" "$length"
  else
    core.manager.async.versions "$manager"
    command.status.update_table "$manager" 0
  fi
}

#
# Installs package $2 of manager $1
#
command.install.package() {
  local manager="$1"
  local package="$2"

  local cmd
  "managers.${manager}.package.install_command" "$package" "$QUIET"
  local msg="${BOLD}Run ${YELLOW}${cmd[*]}${NO_COLOR}${BOLD}?${NO_COLOR}"

  if $SIMULATE; then
    print.confirm "$msg" "no"
    return
  fi

  if print.confirm "$msg"; then
    ${cmd[*]}
  fi
}

command.install() {
  local manager="$1"

  $IN_TERMINAL && print.info "${BOLD}${BLUE}$manager${NO_COLOR} (...)"

  local manager_version
  core.manager.version "$manager" > /dev/null
  manager_version=$(core.manager.version "$manager")

  print.clear.line
  print.info "${BOLD}${BLUE}$manager${NO_COLOR} ($manager_version)"

  # Cache list
  core.manager.cache_list "$manager"

  IFS='
'
  for line in $(core.csv.get "$manager"); do
    local array
    IFS=',' read -ra array <<< "$line"
    IFS=' '

    local package="${array[0]}"

    $IN_TERMINAL && print.info "${BOLD}$package${NO_COLOR} ..."

    local exists=false
    core.package.exists "$manager" "$package" && exists=true

    if ! $exists; then
      print.clear.line
      print.error "${BOLD}$manager's $package${NO_COLOR} does not exists" 2
      continue
    fi

    local local_version
    local remote_version
    local is_installed=false
    local is_uptodate=false

    core.package.version.local "$manager" "$package" > /dev/null
    local_version=$(core.package.version.local "$manager" "$package")
    remote_version=$(core.package.version.remote "$manager" "$package")
    core.package.is_installed "$manager" "$package" && is_installed=true
    core.package.is_uptodate  "$manager" "$package" && is_uptodate=true

    print.clear.line

    if $is_installed; then
      if $is_uptodate; then
        print.success "${BOLD}$manager's $package${NO_COLOR} is up-to-date (${BOLD}$local_version${NO_COLOR})"
      else
        print.warning "${BOLD}$manager's $package${NO_COLOR} is not up-to-date (local: ${BOLD}$local_version${NO_COLOR}, remote: ${BOLD}$remote_version${NO_COLOR})"
        command.install.package "$manager" "$package" "$QUIET"
      fi
    else
      local msg="${BOLD}$manager's $package${NO_COLOR} is not installed (remote: ${BOLD}$remote_version${NO_COLOR})"
      if [[ $COMMAND == "install" ]]; then
        print.warning "$msg"
        command.install.package "$manager" "$package"
      else
        print.warning "$msg, run ${BOLD}${YELLOW}install${NO_COLOR} to install"
      fi
    fi
  done
}

command.update() {
  local manager="$1"

  command.install "$manager"
}

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
  local managers=()
  helpers.is_set "$SYSTEM_MANAGER" && managers+=("$SYSTEM_MANAGER")
  managers+=("${NON_SYSTEM_MANAGERS[@]}")

  local length
  length=$(array.length managers[@])

  # For each managers
  local j=0
  for i in $(seq 0 $((length - 1))); do
    local manager="${managers[$i]}"

    # Pass if is ignored or CSV not found
    core.manager.is_ignored "$manager" && continue
    core.csv.exists         "$manager" || continue
    core.csv.is_empty       "$manager" && continue
    (( j != 0 )) && print.separator
    j=$((j + 1))

    # Pass with warning if manager is not found
    if ! core.manager.exists "$manager"; then
      print.warning "${BOLD}$manager${NO_COLOR} not found"
      continue
    fi

    command.${COMMAND} "$manager"
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

