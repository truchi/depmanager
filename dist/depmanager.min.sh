#!/usr/bin/env bash
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

PACKAGE_NONE="<NONE>"
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

PACKAGE_NONE="<NONE>"
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

helpers.is_set() {
  [[ -n "$1" ]]
}

helpers.file_exists() {
  [[ -f "$1" ]]
}

helpers.url_exists() {
  wget -q --spider "$1"
}

helpers.command_exists() {
  command -v "$1" >/dev/null 2>&1
}

helpers.is_subshell() {
  [ "$$" -ne "$BASHPID" ]
}

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

  if $read_cache && helpers.is_set "${__cache[$cache_key]}"; then
    string="${__cache[$cache_string_key]}"
    code=${__cache[$cache_code_key]}
  else
    args=("${args[@]:4}")

    string=$($cmd "${args[@]}")
    code="$?"

    if $write_cache; then
      if helpers.is_subshell; then
        echo "HELPERS.CACHE CANNOT WRITE IN A SUBSHELL (key: $cache_key, cmd: $cmd)"
        kill $$
        exit
      fi

      __cache[$cache_key]="true"
      __cache[$cache_string_key]="$string"
      __cache[$cache_code_key]=$code
    fi
  fi

  ! string.is_empty "$string" && echo "$string"
  return $code
}

helpers.sanitize_csv() {
  local lines=""
  local packages=()

  while read -ra line; do
    line=$(sed 's/[[:space:]]*//g' <<< "${line[*]}")

    [[ $(string.length "$line") == 0 ]] && continue

    local package
    IFS=, read -ra package <<< "$line"
    [[ $(string.length "$package") == 0 ]] && continue

    array.includes "$package" packages[@] && continue
    packages+=("$package")

    line=$(sed 's/,$//g' <<< "$line")

    lines+="$line
"
  done

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

string.is_absolute() {
  [[ "$1" =~ / ]]
}

string.is_url() {
  [[ "$1" =~ https?:// ]]
}

string.contains() {
  [[ "$1" == *"$2"* ]]
}

string.replace() {
  echo "${1//$2/$3}"
}

string.equals() {
  [[ "$1" == "$2" ]]
}

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

array.length() {
  local array=("${!1}")
  echo "${#array[*]}"
}

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
  $YES && return

  local reply
  reply=$(print.input 1 "${BOLD}$*${NO_COLOR} (${BOLD}${YELLOW}Y${NO_COLOR})")

  [[ ! "$reply" =~ ^$ ]] && echo

  local confirmed=false
  local answer="no"
  if [[ "$reply" =~ ^[Yy]$ || "$reply" =~ ^$ ]]; then
    confirmed=true
    answer="yes"
  fi

  tput cuu1
  tput el
  print.fake.input "${BOLD}$*${NO_COLOR} (${BOLD}${YELLOW}Y${NO_COLOR})" "${BOLD}${YELLOW}$answer${NO_COLOR}"

  $confirmed
}

print.input() {
  local n="$1"
  local message="$2"

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
  ! $SIMULATE && print.info "${BOLD}${BLUE}Tip${NO_COLOR}: run with --simulate first"

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

PACKAGE_NONE="<NONE>"
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

core.dir.resolve() {
  local dir=""

  if helpers.is_set "$DEPMANAGER_DIR"; then
    dir="$DEPMANAGER_DIR"

    ! string.is_absolute "$dir" && dir="$HOME/$dir"
  else
    dir="${DEFAULTS[dir]}"
  fi

  CSVS[dir]="$dir"
}

core.csv.path() {
  local manager="$1"
  local file="${CSVS[$1]}"

  if helpers.is_set "$file"; then
    if [[ "$file" != "ignore" ]]; then
      file="${file/#\~/$HOME}"

      ! string.is_absolute "$file" && ! string.is_url "$file" && file="$(realpath -m "$file")"
    fi
  else
    file="${CSVS[dir]}/${DEFAULTS[$manager]}"
  fi

  CSVS[$manager]="$file"
  echo "$file"
}

core.csv.exists() {
  local manager="$1"
  local cache="$2"

  if core.manager.is_ignored "$manager"; then
    true
    return
  fi

  if string.is_empty "$cache"; then
    cache=true
  fi

  local file
  file=$(core.csv.path "$manager")

  local cmd
  if string.is_url "$file"; then cmd="helpers.url_exists $file"
  else                           cmd="helpers.file_exists $file"
  fi

  helpers.cache \
    "core_csv_exists__$file" \
    "$cache" \
    "$cache" \
    "$cmd"
}

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

core.csv.is_empty() {
  local manager="$1"
  local i=0

  while IFS=, read -ra line; do
    helpers.is_set "${line[0]}" && i=$((i + 1))
  done < <(core.csv.get "$manager")

  ! ((i > 0))
}

core.manager.system() {
  helpers.is_set "$SYSTEM_MANAGER" && return

  for manager in "${SYSTEM_MANAGERS[@]}"; do
    if core.manager.exists "$manager"; then
      SYSTEM_MANAGER="$manager"
      core.manager.version "$SYSTEM_MANAGER" > /dev/null
      return
    fi
  done
}

core.manager.is_system() {
  array.includes "$1" SYSTEM_MANAGERS[@]
}

core.manager.is_ignored() {
  [[ $(core.csv.path "$1") == "ignore" ]]
}


core.manager.exists() {
  local manager="$1"

  helpers.cache \
    "core_manager_exists__$manager" \
    true \
    "$(core.manager.is_system "$manager" && echo true || echo false)" \
    "managers.${manager}.exists"
}

core.manager.version() {
  local manager="$1"

  helpers.cache \
    "core_manager_version__$manager" \
    true \
    true \
    "managers.${manager}.version"
}

core.package.exists() {
  local manager="$1"
  local package="$2"
  local version

  core.package.remote_version "$manager" "$package" > /dev/null

  [[ $(core.package.remote_version "$manager" "$package") != "$PACKAGE_NONE" ]]
}

core.package.is_installed() {
  local manager="$1"
  local package="$2"
  local version

  core.package.local_version "$manager" "$package" > /dev/null

  [[ $(core.package.local_version "$manager" "$package") != "$PACKAGE_NONE" ]]
}

core.package.is_up_to_date() {
  local manager="$1"
  local package="$2"
  local local_version
  local remote_version

  core.package.local_version "$manager" "$package" > /dev/null
  core.package.remote_version "$manager" "$package" > /dev/null

  local_version=$(core.package.local_version "$manager" "$package")
  remote_version=$(core.package.remote_version "$manager" "$package")

  [[ "$local_version" == "$remote_version" ]]
}


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

managers.apt.exists() {
  helpers.command_exists apt && helpers.command_exists apt-cache && helpers.command_exists dpkg
}

managers.apt.version() {
  apt --version
}

managers.apt.package.local_version() {
  local dpkg_list
  dpkg_list=$(dpkg -l "$1" 2> /dev/null)

  if [[ $? != 0 ]]; then
    echo "$PACKAGE_NONE"
    return
  fi

  dpkg_list=$(sed '6q;d' <<< "$dpkg_list")

  if [[ $(string.slice "$dpkg_list" 1 1) == "n" ]]; then
    echo "$PACKAGE_NONE"
    return
  fi

  sed 's/\S*\s*\S*\s*\(\S*\).*/\1/' <<< "$dpkg_list"
}

managers.apt.package.remote_version() {
  local policy
  policy=$(apt-cache policy "$1")

  if [[ "$policy" == "" ]]; then
    echo "$PACKAGE_NONE"
    return
  fi

  echo "$policy" | sed '3q;d' | sed 's/  Candidate: \(.*\).*/\1/'
}

managers.npm.exists() {
  helpers.command_exists npm
}

managers.npm.version() {
  npm --version
}

managers.npm.package.is_installed() {
  local dependency=$1
  local list
  list=$(npm list --global --depth 0 "$dependency")

  echo "$list" | grep "── $dependency@" >/dev/null 2>&1
}

managers.npm.package.local_version() {
  local npm_list
  npm_list=$(npm list --global --depth 0 "$1" | sed '2q;d' | sed 's/└── //')

  if [[ "$npm_list" == "(empty)" ]]; then
    echo "$PACKAGE_NONE"
    return
  fi

  sed 's/.*@//' <<< "$npm_list"
}

managers.npm.package.remote_version() {
  local version
  version=$(npm view "$1" version 2> /dev/null)

  if [[ $? != 0 ]]; then
    echo "$PACKAGE_NONE"
    return
  fi

  echo "$version"
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

    local path
    local is_ignored
    local exists
    local default_path
    local default_color
    path=$(core.csv.path "$manager")
    is_ignored=$(core.manager.is_ignored "$manager" && echo true || echo false)
    exists=$(core.csv.exists "$manager" false && echo true || echo false)

    default_path="ignore"
    default_color="${BLUE}"
    if ! $is_ignored && $exists; then
      default_color="$GREEN"
      default_path="$path"
    fi

    local first=true
    while $first || (! $is_ignored && ! $exists); do
      local message
      local color
      local new_path

      if $first && ! $is_ignored && ! $exists; then
        print.error "${RED}$path${NO_COLOR} not found"
      fi

      message="CSV (${default_color}$default_path${NO_COLOR}):"
      new_path=$(print.input 0 "$message")
      [[ "$new_path" =~ ^$ ]] && new_path="$default_path"
      CSVS[$manager]="$new_path"

      path=$(core.csv.path "$manager")
      is_ignored=$(core.manager.is_ignored "$manager" && echo true || echo false)
      exists=$(core.csv.exists "$manager" false && echo true || echo false)

      tput cuu1
      tput el
      if $is_ignored; then
        print.info "$message ${BLUE}$path${NO_COLOR}"
      elif $exists; then
        print.success "$message ${GREEN}$path${NO_COLOR}"
      else
        print.error "$message ${RED}$path${NO_COLOR}"
      fi

      first=false
    done
  done

  print.separator

  local message="${BOLD}Command?${NO_COLOR} "
  message+="(${BOLD}${YELLOW}S${NO_COLOR}tatus/"
  message+="${BOLD}${YELLOW}i${NO_COLOR}nstall/"
  message+="${BOLD}${YELLOW}u${NO_COLOR}pdate)"

  local cmd
  cmd=$(print.input 1 "$message")

  [[ ! "$cmd" =~ ^$ ]] && echo

  if   [[ "$cmd" =~ ^[i]$ ]]; then COMMAND="install"
  elif [[ "$cmd" =~ ^[u]$ ]]; then COMMAND="update"
  else                             COMMAND="status"
  fi

  tput cuu1
  tput el
  print.fake.input "$message" "${BOLD}${YELLOW}$COMMAND${NO_COLOR}"

  if [[ $COMMAND != "status" ]]; then
    local message="${BOLD}Flags?${NO_COLOR} "
    message+="(${BOLD}${YELLOW}q${NO_COLOR}uiet/"
    message+="${BOLD}${YELLOW}y${NO_COLOR}es/"
    message+="${BOLD}${YELLOW}s${NO_COLOR}imulate)"

    local flags
    flags=$(print.input 3 "$message")

    (( $(string.length "$flags") == 3 )) && echo

    local answer=""
    if [[ "$flags" =~ [qQ] ]]; then QUIET=true   ; answer+="quiet "   ; fi
    if [[ "$flags" =~ [yY] ]]; then YES=true     ; answer+="yes "     ; fi
    if [[ "$flags" =~ [sS] ]]; then SIMULATE=true; answer+="simulate "; fi

    tput cuu1
    tput el
    print.fake.input "$message" "${BOLD}${YELLOW}$answer${NO_COLOR}"
  fi
}

command.status.update_table() {
  local manager=$1
  local remove=$2
  local headers
  headers=("${BLUE}${BOLD}Package${NO_COLOR}" "${BLUE}${BOLD}Local${NO_COLOR}" "${BLUE}${BOLD}Remote${NO_COLOR}")
  local levels=()
  local messages=()

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
      [[ "$local_version" != "$PACKAGE_NONE"   ]] && installed=true
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

  for i in $(seq 1 "$remove"); do
    tput cuu1
  done

  table.print "$title" headers[@] levels[@] messages[@]
}

command.status.manager.version() {
  local manager=$1

  local version
  version=$(core.manager.version "$manager")

  until [ -p "$FIFO" ]; do sleep 0.1; done
  echo "${manager}_version,$version" >"$FIFO"
}

command.status.package.version() {
  local version_type=$1
  local dependency=$2

  local version
  version=$("core.package.${version_type}_version" "$manager" "$dependency" false)

  until [ -p "$FIFO" ]; do sleep 0.1; done
  echo "${dependency}_${version_type}_version,$version" > "$FIFO"
}

command.status() {
  local manager=$1
  declare -A statuses

  [ -p "$FIFO" ] && rm "$FIFO"

  command.status.manager.version "$manager" &

  local line_count=0
  while IFS=, read -ra line; do
    local dependency=${line[0]}

    command.status.package.version "local"  "$dependency" &
    command.status.package.version "remote" "$dependency" &

    line_count=$((line_count + 1))
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

    sleep 1s
    "$redraw" && command.status.update_table "$manager" $((line_count + 2))

    j=$((j + 1))
    (( j == $((line_count * 2 + 1)) )) && break
  done <"$FIFO"

  ! "$redraw" && command.status.update_table "$manager" 0
}

command.install() {
  local manager=$1
  local file
  file=$(core.csv.path "$manager")

  print.info "${BOLD}$manager${NO_COLOR}"

  local i=1
  while IFS=, read -ra line; do
    local dependency=${line[0]}
    print.info "$dependency"

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
  done < <(core.csv.get "$manager")
}

command.update() {
  echo UPDATE
}

main.parse_args() {
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

main.run() {
  declare -a managers
  managers=("$SYSTEM_MANAGER" "${NON_SYSTEM_MANAGERS[@]}")

  local length
  length=$(array.length managers[@])

  local j=0
  for i in $(seq 0 $((length - 1))); do
    local manager="${managers[$i]}"

    core.manager.is_ignored "$manager" && continue
    core.csv.exists         "$manager" || continue
    (( j != 0 )) && print.separator
    j=$((j + 1))

    if ! core.manager.exists "$manager"; then
      print.warning "${BOLD}$manager${NO_COLOR} not found"
      continue
    fi

    core.manager.version "$manager" > /dev/null
    core.csv.get         "$manager" > /dev/null

    if core.csv.is_empty "$manager"; then
      print.warning "${BOLD}${BLUE}$manager${NO_COLOR} CSV is empty"
    else
      command.${COMMAND} "$manager"
    fi
  done
}

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

main "$@"

