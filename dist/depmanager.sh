#!/usr/bin/env bash
#
# Dependencies managment
# Author: Romain TRUCHI (https://github.com/truchi)
#
# # depmanager
#
# Checks, diffs, installs or updates your dependencies.
# System, NodeJS, Rust.
#
# # Dependencies
#
# bash, wget (remote CSV only)
#
# # Usage
#
# $ depmanager check --directory ~/my/dir --npm ~/my/npm.csv
#
# # Configuration
#
# `$DEPMANAGER_DIR="/path/to/your/dir"` # No trailing slash
# Defaults to "$HOME/.config/depmanager"

SYSTEM_MANAGERS=(apt)
NON_SYSTEM_MANAGERS=(npm rust)
MANAGERS=("${SYSTEM_MANAGERS[@]}" "${NON_SYSTEM_MANAGERS[@]}")

SYSTEM_MANAGER=
COMMAND=
QUIET=false
YES=false
SIMULATE=false

declare -A __cache
declare -A CSVS
declare -A DEFAULTS
DEFAULTS[dir]="$HOME/.config/depmanager"
for manager in "${MANAGERS[@]}"; do
  DEFAULTS[$manager]="$manager.csv"
done

DEPMANAGER_CACHE_DIR="/tmp/depmanager"
FIFO="$DEPMANAGER_CACHE_DIR/fifo"
mkdir -p "$DEPMANAGER_CACHE_DIR"

if [ -t 1 ]; then
  NO_COLOR=$(tput sgr0)
  BOLD=$(tput bold)
  RED=$(tput setaf 1)
  GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3)
  BLUE=$(tput setaf 4)
  MAGENTA=$(tput setaf 5)
  CYAN=$(tput setaf 6)
  WHITE=$(tput setaf 7)
fi

SYSTEM_MANAGERS=(apt)
NON_SYSTEM_MANAGERS=(npm rust)
MANAGERS=("${SYSTEM_MANAGERS[@]}" "${NON_SYSTEM_MANAGERS[@]}")

SYSTEM_MANAGER=
COMMAND=
QUIET=false
YES=false
SIMULATE=false

declare -A __cache
declare -A CSVS
declare -A DEFAULTS
DEFAULTS[dir]="$HOME/.config/depmanager"
for manager in "${MANAGERS[@]}"; do
  DEFAULTS[$manager]="$manager.csv"
done

DEPMANAGER_CACHE_DIR="/tmp/depmanager"
FIFO="$DEPMANAGER_CACHE_DIR/fifo"
mkdir -p "$DEPMANAGER_CACHE_DIR"

if [ -t 1 ]; then
  NO_COLOR=$(tput sgr0)
  BOLD=$(tput bold)
  RED=$(tput setaf 1)
  GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3)
  BLUE=$(tput setaf 4)
  MAGENTA=$(tput setaf 5)
  CYAN=$(tput setaf 6)
  WHITE=$(tput setaf 7)
fi

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
# Caches the return code and echoed string of a function
# DO NOT call from subshell: memory would not be written, script will die
#
helpers.cache() {
  local args=("$@")
  local cache_key="$1"
  local read_cache="$2"
  local write_cache="$3"
  local cmd="$4"

  local cache_string_key="__${cache_key}__string"
  local cache_code_key="__${cache_key}__code"
  local string
  local code

  # Read from cache or execute
  if $read_cache && helpers.is_set "${__cache[$cache_key]}"; then
    string="${__cache[$cache_string_key]}"
    code=${__cache[$cache_code_key]}
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

      __cache[$cache_key]="true"
      __cache[$cache_string_key]="$string"
      __cache[$cache_code_key]=$code
    fi
  fi

  # Echo string and return code
  ! string.is_empty "$string" && echo "$string"
  return $code
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

print.separator() {
  $QUIET && return
  echo "${MAGENTA}~~~~~~~~~~~~~~~~~~~~~${NO_COLOR}"
}

print.date() {
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
  # Auto confirm if flag is given
  $YES && return

  # Prompt confirmation message
  local reply
  reply=$(print.input 1 "${BOLD}$*${NO_COLOR} (${BOLD}${YELLOW}Y${NO_COLOR})")

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
  tput cuu1
  print.fake.input "${BOLD}$*${NO_COLOR} (${BOLD}${YELLOW}Y${NO_COLOR})" "${BOLD}${YELLOW}$answer${NO_COLOR}"

  $confirmed
}

print.fake.confirm() {
  local message="$1"
  local answer="$2"

  print.fake.input "${BOLD}$message${NO_COLOR} (${BOLD}${YELLOW}Y${NO_COLOR})" "$answer"
}

print.input() {
  local n="$1"
  local message="$2"

  # Prompt input
  if ((n == 0)); then
    read -p "$(print.date) ${YELLOW}${BOLD}?${NO_COLOR} $message " -r
  else
    read -p "$(print.date) ${YELLOW}${BOLD}?${NO_COLOR} $message " -n "$n" -r
  fi

  echo "$REPLY"
}

print.fake.input() {
  local message="$1"
  local answer="$2"

  echo "$(print.date) ${YELLOW}${BOLD}?${NO_COLOR} $message $answer"
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
  ${BOLD}${GREEN}$cmd${NO_COLOR} <cmd> [options|flags]

${BOLD}${BLUE}Description:${NO_COLOR}
  ${WHITE}Manages your dependencies.

  List packages you depend on in CSV files.
  Export \$DEPMANAGER_DIR environment variable (defaults to \$HOME/.config/depmanager).${NO_COLOR}

${BOLD}${BLUE}Commands:${NO_COLOR}
  I${WHITE},${NO_COLOR} interactive                 ${WHITE}Runs in interactive mode${NO_COLOR}
  s${WHITE},${NO_COLOR} status                      ${WHITE}Produces a report with regard to the CSV files${NO_COLOR}
  i${WHITE},${NO_COLOR} install                     ${WHITE}Installs packages in the CSV files${NO_COLOR}
  u${WHITE},${NO_COLOR} update                      ${WHITE}Updates packages in the CSV files${NO_COLOR}

${BOLD}${BLUE}Options:${NO_COLOR}
  -a${WHITE},${NO_COLOR} --apt    <path|url|false>  ${WHITE}Blah${NO_COLOR}
  -y${WHITE},${NO_COLOR} --yum    <path|url|false>  ${WHITE}Blah${NO_COLOR}
  -p${WHITE},${NO_COLOR} --pacman <path|url|false>  ${WHITE}Blah${NO_COLOR}
  -n${WHITE},${NO_COLOR} --npm    <path|url|false>  ${WHITE}Blah${NO_COLOR}
  -r${WHITE},${NO_COLOR} --rust   <path|url|false>  ${WHITE}Blah${NO_COLOR}

${BOLD}${BLUE}Flags:${NO_COLOR}
  -Q${WHITE},${NO_COLOR} --quiet                    ${WHITE}Blah${NO_COLOR}
  -Y${WHITE},${NO_COLOR} --yes                      ${WHITE}Blah${NO_COLOR}
  -S${WHITE},${NO_COLOR} --simulate                 ${WHITE}Blah${NO_COLOR}

${BOLD}${BLUE}Links:${NO_COLOR}
  ${WHITE}- Repository${NO_COLOR}                   ${MAGENTA}https://github.com/truchi/depmanager${NO_COLOR}
  ${WHITE}- Website${NO_COLOR}                      ${MAGENTA}https://github.com/truchi/depmanager${NO_COLOR}
  ${WHITE}- Documentation${NO_COLOR}                ${MAGENTA}https://github.com/truchi/depmanager${NO_COLOR}
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
    if   core.manager.is_bypassed "$manager"; then messages+=("${BLUE}ignored${NO_COLOR}")
    elif core.csv.exists          "$manager"; then messages+=("${GREEN}$(core.csv.path  "$manager")${NO_COLOR}")
    else                                           messages+=("${YELLOW}$(core.csv.path "$manager")${NO_COLOR}")
    fi

    if   core.manager.is_bypassed "$manager"; then  levels+=("info")
    elif core.csv.exists          "$manager"; then  levels+=("success")
    else                                            levels+=("warning")
    fi

    i=$((i + 1))
  done

  table.print "" 2 levels[@] messages[@]
}

print.pre_run_confirm() {
  ! $SIMULATE && print.info "${BOLD}${BLUE}Tip${NO_COLOR}: run with --simulate first"

  # Ask for confirmation
  if $SIMULATE; then print.confirm "Simulate $COMMAND?"
  else               print.confirm "Run $COMMAND?"
  fi
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
declare -A CSVS
declare -A DEFAULTS
DEFAULTS[dir]="$HOME/.config/depmanager"
for manager in "${MANAGERS[@]}"; do
  DEFAULTS[$manager]="$manager.csv"
done

DEPMANAGER_CACHE_DIR="/tmp/depmanager"
FIFO="$DEPMANAGER_CACHE_DIR/fifo"
mkdir -p "$DEPMANAGER_CACHE_DIR"

if [ -t 1 ]; then
  NO_COLOR=$(tput sgr0)
  BOLD=$(tput bold)
  RED=$(tput setaf 1)
  GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3)
  BLUE=$(tput setaf 4)
  MAGENTA=$(tput setaf 5)
  CYAN=$(tput setaf 6)
  WHITE=$(tput setaf 7)
fi

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
# Returns CSV path for manager $1
#
core.csv.path() {
  echo "${CSVS[$1]}"
}

#
# Sets $1 manager's CSV according to (in this precedence order):
# - cli arg          (relative to current workin directory)
# - default variable (relative to `CSVS[dir]`, see core.dir.resolve)
#
core.csv.resolve() {
  local manager="$1"
  local file
  file=$(core.csv.path "$manager")

  # If file is given in args
  if helpers.is_set "$file"; then
    # Expand ~
    file="${file/#\~/$HOME}"

    # Relative to current working dir
    ! string.is_absolute "$file" && ! string.is_url "$file" && file="$(realpath -m "$file")"
  else
    # Use default file, relative to CSVS[dir]
    file="${CSVS[dir]}/${DEFAULTS[$manager]}"
  fi

  CSVS[$manager]="$file"
}

#
# Returns true if $1 manager's CSV exists (file/url), false otherwise
# With cache
#
core.csv.exists() {
  local manager="$1"
  local read_cache="$2"

  if string.is_empty "$read_cache"; then
    read_cache=true
  fi

  local file
  file=$(core.csv.path "$manager")

  local cmd
  if string.is_url "$file"; then cmd="helpers.url_exists $file"
  else                           cmd="helpers.file_exists $file"
  fi

  helpers.cache \
    "core_csv_exists__$file" \
    "$read_cache" \
    true \
    "$cmd"
}

#
# Returns content of $1 manager's CSV
# With cache
#
core.csv.get() {
  local manager="$1"
  local file
  file=$(core.csv.path "$manager")

  helpers.cache "core_csv_get__$file" true true "__core.csv.get" "$file"
}

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
core.csv.is_empty() {
  local manager="$1"
  local i=0

  # Count non-empty lines
  while IFS=, read -ra line; do
    # TODO should account whitespaces as empty lines
    helpers.is_set "${line[0]}" && i=$((i + 1))
  done < <(core.csv.get "$manager")

  # Do we have non-empty lines?
  ! ((i > 0))
}

#
# Sets `SYSTEM_MANAGER` to the first found system manager
#
core.manager.system() {
  # Already detected?
  helpers.is_set "$SYSTEM_MANAGER" && return

  # Try all system managers
  for manager in "${SYSTEM_MANAGERS[@]}"; do
    if core.manager.exists "$manager"; then
      SYSTEM_MANAGER="$manager"
      # Init cache for version
      core.manager.version "$SYSTEM_MANAGER" > /dev/null
      return
    fi
  done
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
core.manager.is_bypassed() {
  [[ $(core.csv.path "$1") == false ]]
}

###############################################################
# Functions below cache corresponding functions in managers/ #
###############################################################

#
# Returns true if manager $1 is found on the system, false otherwise
# With cache (system managers only)
#
core.manager.exists() {
  local manager="$1"

  helpers.cache \
    "core_manager_exists__$manager" \
    true \
    "$(core.manager.is_system "$manager" && echo true || echo false)" \
    "managers.${manager}.exists"
}

#
# Returns manager $1 version
# With cache
#
core.manager.version() {
  local manager="$1"

  helpers.cache \
    "core_manager_version__$manager" \
    true \
    true \
    "managers.${manager}.version"
}

###############################################################
# Functions below cache corresponding functions in managers/ #
###############################################################

#
# Returns true if dependency $2 of manager $1 is installed, false otherwise
# With cache
#
core.package.is_installed() {
  local manager="$1"
  local package="$2"
  local write_cache="$3"

  if string.is_empty "$write_cache"; then
    write_cache=true
  fi

  helpers.cache \
    "core_package_is_installed__${manager}__${package}" \
    true \
    "$write_cache" \
    "managers.${manager}.package.is_installed $package"
}

#
# Returns the local version of dependency $2 of manager $1
# With cache
#
core.package.local_version() {
  local manager="$1"
  local package="$2"
  local write_cache="$3"

  if string.is_empty "$write_cache"; then
    write_cache=true
  fi

  helpers.cache \
    "core_package_local_version__${manager}__${package}" \
    true \
    "$write_cache" \
    "managers.${manager}.package.local_version $package"
}

#
# Returns the remote version of dependency $2 of manager $1
# With cache
#
core.package.remote_version() {
  local manager="$1"
  local package="$2"
  local write_cache="$3"

  if string.is_empty "$write_cache"; then
    write_cache=true
  fi

  helpers.cache \
    "core_package_remote_version__${manager}__${package}" \
    true \
    "$write_cache" \
    "managers.${manager}.package.remote_version $package"
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
# Returns true if dependency $1 is installed, false otherwise
#
managers.apt.package.is_installed() {
  local dependency=$1
  local list
  list=$(apt list --installed "$dependency" 2>/dev/null | sed 's/Listing...//')

  echo "$list" | grep "^$dependency/" | grep '\[installed' >/dev/null 2>&1
}


#
# Returns the local version of dependency $1
#
managers.apt.package.local_version() {
  apt-cache policy "$1" | sed '2q;d' | sed 's/  Installed: \(.*\).*/\1/'
}

#
# Returns the remote version of dependency $1
#
managers.apt.package.remote_version() {
  apt-cache policy "$1" | sed '3q;d' | sed 's/  Candidate: \(.*\).*/\1/'
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

#
# Returns true if dependency $1 is installed, false otherwise
#
managers.npm.package.is_installed() {
  local dependency=$1
  local list
  list=$(npm list --global --depth 0 "$dependency")

  echo "$list" | grep "── $dependency@" >/dev/null 2>&1
}

#
# Returns the local version of dependency $1
#
managers.npm.package.local_version() {
  npm list --global --depth 0 "$1" | sed '2q;d' | sed 's/└── .*@//'
}

#
# Returns the remote version of dependency $1
#
managers.npm.package.remote_version() {
  npm view "$1" version
}

command.interactive() {
  local managers
  local length
  managers=("$SYSTEM_MANAGER" "${NON_SYSTEM_MANAGERS[@]}")
  length=$(array.length managers[@])

  for i in $(seq 0 $((length - 1))); do
    local manager="${managers[$i]}"

    [[ $i != 0 ]] && print.separator
    print.info "${BOLD}$manager${NO_COLOR}"

    local first=true
    local path
    local default_path=false
    local color="$BLUE"

    while true; do
      if core.manager.is_bypassed "$manager"; then
        default_path=false
        color="$BLUE"
      else
        core.csv.resolve "$manager"

        if core.csv.exists "$manager" false; then
          ! $first && break
          default_path=$(core.csv.path "$manager")
          color="$GREEN"
        else
          print.warning "${YELLOW}$path${NO_COLOR} not found"
          default_path=false
          color="$BLUE"
        fi
      fi

      path=$(print.input 0 "CSV (${color}$default_path${NO_COLOR}):")
      [[ "$path" =~ ^$ ]] && path="$default_path"
      CSVS[$manager]=$path

      [[ "$path" == false ]] && break
      first=false
    done
  done

  print.separator

  # Ask for command
  local message="${BOLD}Command?${NO_COLOR} "
  message+="(${BOLD}${YELLOW}S${NO_COLOR}tatus/"
  message+="${BOLD}${YELLOW}i${NO_COLOR}nstall/"
  message+="${BOLD}${YELLOW}u${NO_COLOR}pdate)"

  local cmd
  cmd=$(print.input 1 "$message")

  if   [[ "$cmd" =~ ^[i]$ ]]; then COMMAND="install"
  elif [[ "$cmd" =~ ^[u]$ ]]; then COMMAND="update"
  else                             COMMAND="status"
  fi

  # Carriage return if user did not press enter
  [[ ! "$cmd" =~ ^$ ]] && echo

  # Redraw with answer
  tput cuu1
  print.fake.input "$message" "${BOLD}${YELLOW}$COMMAND${NO_COLOR}"

  # Ask for simulate
  if [[ $COMMAND != "status" ]] && print.confirm "Simulate?"; then
    SIMULATE=true
  fi
}

command.status.update_table() {
  local manager=$1
  local remove=$2
  local headers
  headers=("${BLUE}${BOLD}Package${NO_COLOR}" "${BLUE}${BOLD}Local${NO_COLOR}" "${BLUE}${BOLD}Remote${NO_COLOR}")
  local levels=()
  local messages=()

  ((remove > 0)) && echo -e "$(tput cuu "$remove")"

  local i=1
  while IFS=, read -ra line; do
    local dependency=${line[0]}
    ! helpers.is_set "$dependency" && continue

    local local_version="${statuses[${dependency}_local_version]}"
    local remote_version="${statuses[${dependency}_remote_version]}"
    local local_version_done
    local remote_version_done
    local_version_done=$(helpers.is_set "$local_version" && echo true || echo false)
    remote_version_done=$(helpers.is_set "$remote_version" && echo true || echo false)

    messages+=("${BOLD}$dependency${NO_COLOR}")
    $local_version_done  && messages+=("$local_version")  || messages+=("...")
    $remote_version_done && messages+=("$remote_version") || messages+=("...")

    if $local_version_done && $remote_version_done; then
      local installed=false
      local up_to_date=false
      [[ "$local_version" != "NONE"            ]] && installed=true
      [[ "$local_version" == "$remote_version" ]] && up_to_date=true

      if   ! $installed; then levels+=("error")
      elif $up_to_date ; then levels+=("success")
      else                    levels+=("warning")
      fi
    else
      levels+=("info")
    fi

    i=$((i + 1))
  done < <(core.csv.get "$manager")

  local manager_version="${statuses[${manager}_version]}"
  local title

  if helpers.is_set "$manager_version"; then
    title="${BLUE}${BOLD}$manager${NO_COLOR} ($manager_version)"
  else
    title="${BLUE}${BOLD}$manager${NO_COLOR} (...)"
  fi

  table.print "$title" headers[@] levels[@] messages[@]
}

command.status.manager.version() {
  local manager=$1

  local version
  version=$(core.manager.version "$manager")

  until [ -p "$FIFO" ]; do sleep 0.1; done
  echo "${manager}_version,$version" >"$FIFO"
}

command.status.package.local_version() {
  local dependency=$1

  local version="NONE"
  if core.package.is_installed "$manager" "$dependency" false; then
    version=$(core.package.local_version "$manager" "$dependency" false)
  fi

  until [ -p "$FIFO" ]; do sleep 0.1; done
  echo "${dependency}_local_version,$version" >"$FIFO"
}

command.status.package.remote_version() {
  local dependency=$1

  local version
  version=$(core.package.remote_version "$manager" "$dependency" false)
  ! helpers.is_set "$version" && version="NONE"

  until [ -p "$FIFO" ]; do sleep 0.1; done
  echo "${dependency}_remote_version,$version" >"$FIFO"
}

command.status() {
  local manager=$1
  declare -A statuses

  [ -p "$FIFO" ] && rm "$FIFO"

  command.status.manager.version "$manager" &

  local i=0
  while IFS=, read -ra line; do
    local dependency=${line[0]}

    command.status.package.local_version  "$dependency" &
    command.status.package.remote_version "$dependency" &

    i=$((i + 1))
  done < <(core.csv.get "$manager")

  local redraw=false
  [ -t 1 ] && redraw=true

  "$redraw" && command.status.update_table "$manager" 0
  mknod "$FIFO" p

  local j=0
  while true; do
    read -r data
    ! helpers.is_set "$data" && continue

    local array
    IFS=, read -r -a array <<< "$data"
    statuses["${array[0]}"]="${array[1]}"
    "$redraw" && command.status.update_table "$manager" $((i + 3))

    j=$((j + 1))
    (( j == $((i * 2 + 1)) )) && break
  done <"$FIFO"

  ! "$redraw" && command.status.update_table "$manager" 0
}

command.install() {
  local manager=$1
  local file
  file=$(core.csv.path "$manager")

  local i=1
  while IFS=, read -ra line; do
    local dependency=${line[0]}

    local remote_version
    core.package.remote_version "$manager" "$dependency" > /dev/null
    remote_version=$(core.package.remote_version "$manager" "$dependency")
    ! helpers.is_set "$remote_version" && remote_version="NONE"

    local installed=false
    local local_version="NONE"
    local up_to_date
    if core.package.is_installed "$manager" "$dependency"; then
      installed=true
      core.package.local_version "$manager" "$dependency" > /dev/null
      local_version=$(core.package.local_version "$manager" "$dependency")
      up_to_date=$([[ "$local_version" == "$remote_version" ]] && echo true || echo false)
    fi

    if ! $installed; then
      print.info "INSTALL!!!!! $dependency"
    elif $up_to_date; then
      print.success "${BOLD}$dependency${NO_COLOR} is up-to-date ($local_version)"
    else
      print.warning "${BOLD}$dependency${NO_COLOR} is not up-to-date"
    fi

    i=$((i + 1))
  done < "$file"
}

command.update() {
  echo UPDATE
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

  for manager in "${MANAGERS[@]}"; do
    core.manager.is_bypassed "$manager" && continue

    core.csv.resolve "$manager"
    core.csv.exists  "$manager"
  done

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

