#!/usr/bin/env bash
SYSTEM_MANAGERS=(apt yum pacman)
NON_SYSTEM_MANAGERS=(node rust)
MANAGERS=("${SYSTEM_MANAGERS[@]}" "${NON_SYSTEM_MANAGERS[@]}")

SYSTEM_MANAGER=
COMMAND=
QUIET=false
YES=false
SIMULATE=false

declare -A PATHS
declare -A __cache_detect_path
declare -A __cache_detect_manager
declare -A __cache_read_csv

declare -A DEFAULTS
DEFAULTS[dir]="$HOME/.config/depmanager"
for manager in "${MANAGERS[@]}"; do
  DEFAULTS[$manager]="$manager.csv"
done

DEPMANAGER_CACHE_DIR="$HOME/.cache/depmanager"
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

string.substring() {
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

  read -p "$(print.date) ${YELLOW}${BOLD}?${NO_COLOR} ${BOLD}$*${NO_COLOR} ${YELLOW}(Y)${NO_COLOR} " -n 1 -r

  [[ ! "$REPLY" =~ ^$ ]] && echo

  [[ "$REPLY" =~ ^[Yy]$ || "$REPLY" =~ ^$ ]]
}

print.input() {
  read -p "$(print.date) ${YELLOW}${BOLD}?${NO_COLOR} $* " -r

  echo "$REPLY"
}

print.choice() {
  echo "print choice ..."
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
  -n${WHITE},${NO_COLOR} --node   <path|url|false>  ${WHITE}Blah${NO_COLOR}
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
  dir=("${BOLD}Depmanager directory${NO_COLOR}" "${BLUE}$(core.get_path dir)${NO_COLOR}" "($dir)")

  if helpers.is_set "$SYSTEM_MANAGER"; then
    local version
    local levels=("info" "info")
    local messages=("${dir[@]}")
    version=$("${SYSTEM_MANAGER}_version")
    messages+=("${BOLD}System's manager${NO_COLOR}" "${BLUE}$SYSTEM_MANAGER${NO_COLOR}" "($version)")

    table.print "" 3 levels[@] messages[@]
  else
    print.info "${dir[@]}"
    print.warning "${BOLD}Your system's manager is not supported${NO_COLOR}"
  fi
}

print.csv_info() {
  local i=0
  local levels=()
  local messages=()
  for manager in "${MANAGERS[@]}"; do
    if core.is_system_manager "$manager"; then
      ! core.detect_manager "$manager" && continue
    fi

    messages+=("${BOLD}$manager${NO_COLOR}")
    if   core.is_bypassed "$manager"; then messages+=("${BLUE}ignored${NO_COLOR}")
    elif core.detect_path "$manager"; then messages+=("${GREEN}$(core.get_path  "$manager")${NO_COLOR}")
    else                                   messages+=("${YELLOW}$(core.get_path "$manager")${NO_COLOR}")
    fi

    if   core.is_bypassed "$manager"; then  levels+=("info")
    elif core.detect_path "$manager"; then  levels+=("success")
    else                                    levels+=("warning")
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

core.resolve_dir() {
  local dir=""

  if helpers.is_set "$DEPMANAGER_DIR"; then
    dir="$DEPMANAGER_DIR"

    ! string.is_absolute "$dir" && dir="$HOME/$dir"
  else
    dir="${DEFAULTS[dir]}"
  fi

  PATHS[dir]="$dir"
}

core.resolve_path() {
  local manager="$1"
  local file=""

  if helpers.is_set "${PATHS[$manager]}"; then
    file="${PATHS[$manager]}"
    file="${file/#\~/$HOME}"

    ! string.is_absolute "$file" && ! string.is_url "$file" && file="$(realpath -m "$file")"
  else
    file="${PATHS[dir]}/${DEFAULTS[$manager]}"
  fi

  PATHS[$manager]="$file"
}

core.detect_path() {
  local manager="$1"
  local read_cache="$2"
  local file="${PATHS[$manager]}"

  if $read_cache && helpers.is_set "${__cache_detect_path[$manager]}";then
    "${__cache_detect_path[$manager]}"
    return
  fi

  if (string.is_url "$file" && helpers.url_exists "$file") || helpers.file_exists "$file"; then
    __cache_detect_path[$manager]=true
    true
  else
    __cache_detect_path[$manager]=false
    false
  fi
}

core.detect_manager() {
  local manager="$1"

  if helpers.is_set "${__cache_detect_manager[$manager]}"; then
    "${__cache_detect_manager[$manager]}"
    return
  fi

  if helpers.command_exists "${manager}_detect" && "${manager}_detect"; then
    core.is_system_manager "$manager" && __cache_detect_manager[$manager]=true
    true
  else
    core.is_system_manager "$manager" && __cache_detect_manager[$manager]=false
    false
  fi
}

core.detect_system() {
  helpers.is_set "$SYSTEM_MANAGER" && return

  for manager in "${SYSTEM_MANAGERS[@]}"; do
    if core.detect_manager "$manager"; then
      SYSTEM_MANAGER="$manager"
      return
    fi
  done
}

core.read_csv() {
  local manager="$1"
  local file="${PATHS[$manager]}"

  if helpers.is_set "${__cache_read_csv[$manager]}";then
    echo "${__cache_read_csv[$manager]}"
    return
  fi

  local csv
  if string.is_url "$file"; then
    csv=$(wget "$file")
  else
    csv=$(cat "$file")
  fi

  __cache_read_csv[$manager]="$csv"
  echo "$csv"
}

core.csv_is_empty() {
  local manager="$1"
  local i=0

  while IFS=, read -ra line; do
    helpers.is_set "${line[0]}" && i=$((i + 1))
  done < <(core.read_csv "$manager")

  ! ((i > 0))
}

core.is_bypassed() {
  [[ "${PATHS[$1]}" == false ]]
}

core.get_path() {
  echo "${PATHS[$1]}"
}

core.is_system_manager() {
  array.includes "$1" SYSTEM_MANAGERS[@]
}

apt_detect() {
  helpers.command_exists apt && helpers.command_exists apt-cache && helpers.command_exists dpkg
}

apt_version() {
  apt --version
}

apt_is_installed() {
  local dependency=$1
  local list
  list=$(apt list --installed "$dependency" 2>/dev/null | sed 's/Listing...//')

  echo "$list" | grep "^$dependency/" | grep '\[installed' >/dev/null 2>&1
}


apt_get_local_version() {
  apt-cache policy "$1" | sed '2q;d' | sed 's/  Installed: \(.*\).*/\1/'
}

apt_get_remote_version() {
  apt-cache policy "$1" | sed '3q;d' | sed 's/  Candidate: \(.*\).*/\1/'
}

node_detect() {
  helpers.command_exists npm
}

node_version() {
  node --version
}

node_is_installed() {
  local dependency=$1
  local list
  list=$(npm list --global --depth 0 "$dependency")

  echo "$list" | grep "── $dependency@" >/dev/null 2>&1
}

node_get_local_version() {
  npm list --global --depth 0 "$1" | sed '2q;d' | sed 's/└── .*@//'
}

node_get_remote_version() {
  npm view "$1" version
}

run_interactive() {
  local managers
  local length
  managers=("$SYSTEM_MANAGER" "${NON_SYSTEM_MANAGERS[@]}")
  length=$(array.length managers[@])

  for i in $(seq 0 $((length - 1))); do
    local manager="${managers[$i]}"
    ! core.detect_manager "$manager" && continue

    [[ $i != 0 ]] && print.separator
    print.info "${BOLD}$manager${NO_COLOR}"

    local first=true
    local path
    local default_path

    while true; do
      if core.is_bypassed "$manager"; then
        default_path="${BLUE}false${NO_COLOR}"
      else
        core.resolve_path "$manager"

        if core.detect_path "$manager" false; then
          ! $first && break
          default_path="${GREEN}${PATHS[$manager]}${NO_COLOR}"
        else
          default_path="${BLUE}false${NO_COLOR}"
          print.warning "Not found ${YELLOW}${PATHS[$manager]}${NO_COLOR}"
        fi
      fi

      path=$(print.input "CSV ($default_path):")
      [[ "$path" =~ ^$ ]] && path=$(string.strip_sequences "$default_path")
      PATHS[$manager]=$path

      [[ "$path" == false ]] && break
      first=false
    done
  done

}

status_update_table() {
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
  done < <(core.read_csv "$manager")

  local manager_version="${statuses[${manager}_version]}"
  local title

  if helpers.is_set "$manager_version"; then
    title="${BLUE}${BOLD}$manager${NO_COLOR} ($manager_version)"
  else
    title="${BLUE}${BOLD}$manager${NO_COLOR} (...)"
  fi

  table.print "$title" headers[@] levels[@] messages[@]
}

status_get_manager_version() {
  local manager=$1

  local version
  version=$("${manager}_version")

  until [ -p "$FIFO" ]; do sleep 0.1; done
  echo "${manager}_version,$version" >"$FIFO"
}

status_get_local_version() {
  local dependency=$1

  local version="NONE"
  "${manager}_is_installed" "$dependency" && version=$("${manager}_get_local_version" "$dependency")

  until [ -p "$FIFO" ]; do sleep 0.1; done
  echo "${dependency}_local_version,$version" >"$FIFO"
}

status_get_remote_version() {
  local dependency=$1

  local version
  version=$("${manager}_get_remote_version" "$dependency")
  ! helpers.is_set "$version" && version="NONE"

  until [ -p "$FIFO" ]; do sleep 0.1; done
  echo "${dependency}_remote_version,$version" >"$FIFO"
}

run_status() {
  local manager=$1
  declare -A statuses

  [ -p "$FIFO" ] && rm "$FIFO"

  status_get_manager_version "$manager" &

  local i=0
  while IFS=, read -ra line; do
    local dependency=${line[0]}
    ! helpers.is_set "$dependency" && continue

    status_get_local_version  "$dependency" &
    status_get_remote_version "$dependency" &

    i=$((i + 1))
  done < <(core.read_csv "$manager")

  local redraw=false
  [ -t 1 ] && redraw=true

  "$redraw" && status_update_table "$manager" 0
  mknod "$FIFO" p

  local j=0
  while true; do
    read -r data
    ! helpers.is_set "$data" && continue

    local array
    IFS=, read -r -a array <<< "$data"
    statuses["${array[0]}"]="${array[1]}"
    "$redraw" && status_update_table "$manager" $((i + 3))

    j=$((j + 1))
    (( j == $((i * 2 + 1)) )) && break
  done <"$FIFO"

  ! "$redraw" && status_update_table "$manager" 0
}

run_install() {
  local manager=$1
  local file
  file=$(core.get_path "$manager")

  local i=1
  while IFS=, read -ra line; do
    local dependency=${line[0]}
    local installed=false
    local local_version="NONE"
    local remote_version
      remote_version=$("${manager}_get_remote_version" "$dependency")
    local up_to_date

    ! helpers.is_set "$remote_version" && remote_version="NONE"

    if "${manager}_is_installed" "$dependency"; then
      installed=true
      local_version=$("${manager}_get_local_version" "$dependency")
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

run_update() {
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
        PATHS["apt"]="$3"; shift; shift;;
      -y|--yum)
        PATHS["yum"]="$3"; shift; shift;;
      -p|--pacman)
        PATHS["pacman"]="$3"; shift; shift;;
      -n|--node)
        PATHS["node"]="$3"; shift; shift;;
      -r|--rust)
        PATHS["rust"]="$3"; shift; shift;;
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
        flags=$(string.substring "$2" 1)
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

run() {
  declare -a managers
  local length
  managers=("$SYSTEM_MANAGER" "${NON_SYSTEM_MANAGERS[@]}")
  length=$(array.length managers[@])

  for i in $(seq 0 $((length - 1))); do
    local manager="${managers[$i]}"

    core.is_bypassed   "$manager"    && continue
    ! core.detect_path "$manager"    && continue

    [[ $i != 0 ]] && print.separator
    ! core.detect_manager "$manager" && print.warning "${BOLD}$manager${NO_COLOR} not found" && continue

    if core.csv_is_empty "$manager"; then
      print.warning "${BOLD}${BLUE}$manager${NO_COLOR} CSV is empty"
    else
      run_${COMMAND} "$manager"
    fi
  done
}

main() {
  main.parse_args "$@"
  core.resolve_dir
  core.detect_system

  if [[ "$COMMAND" == "interactive" ]]; then
    QUIET=false
    YES=false
  fi

  print.system_info
  print.separator

  for manager in "${MANAGERS[@]}"; do
    core.is_bypassed "$manager" && continue

    core.resolve_path "$manager"
    core.detect_path "$manager"
  done

  if [[ "$COMMAND" == "interactive" ]]; then
    run_interactive
    print.separator
  fi

  print.csv_info
  print.separator

  if [[ $COMMAND == "status" ]]; then
    local old_quiet=$QUIET
    QUIET=false
    run
    QUIET=$old_quiet
  else
    if print.pre_run_confirm; then
      print.info Go!
      print.separator
      run
    else
      print.info Bye!
      exit
    fi
  fi

  print.separator
  print.info Done!
}

main "$@"

