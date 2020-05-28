# shellcheck shell=bash

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
      print.error "${BOLD}$package${NO_COLOR} does not exists" 2
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
        print.success "${BOLD}$package${NO_COLOR} is up-to-date (${BOLD}$local_version${NO_COLOR})"
      else
        print.warning "${BOLD}$package${NO_COLOR} is not up-to-date (local: ${BOLD}$local_version${NO_COLOR}, remote: ${BOLD}$remote_version${NO_COLOR})"
        command.install.package "$manager" "$package" "$QUIET"
      fi
    else
      local msg="${BOLD}$package${NO_COLOR} is not installed (remote: ${BOLD}$remote_version${NO_COLOR})"
      if [[ $COMMAND == "install" ]]; then
        print.warning "$msg"
        command.install.package "$manager" "$package"
      else
        print.warning "$msg, run ${BOLD}${YELLOW}install${NO_COLOR} to install"
      fi
    fi
  done
}

