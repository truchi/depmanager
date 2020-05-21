# shellcheck shell=bash

command.install() {
  local manager=$1
  local file
  file=$(core.csv.path "$manager")

  local manager_version
  core.manager.version "$manager" > /dev/null
  manager_version=$(core.manager.version "$manager")
  print.info "${BOLD}${BLUE}$manager${NO_COLOR} ($manager_version)"

  local i=1
  while IFS=, read -ra line; do
    local dependency=${line[0]}
    print.info "${BOLD}$dependency${NO_COLOR} ..."

    local local_version
    local remote_version
    local exists
    local is_installed
    local is_uptodate

    core.package.remote_version "$manager" "$dependency" > /dev/null
    remote_version=$(core.package.remote_version "$manager" "$dependency")
    exists=$(core.package.exists "$manager" "$dependency" && echo true || echo false)

    if ! $exists; then
      tput cuu1
      tput el
      print.warning "${BOLD}$dependency${NO_COLOR} do not exists"
      continue
    fi

    core.package.local_version "$manager" "$dependency" > /dev/null
    local_version=$(core.package.local_version "$manager" "$dependency")
    is_uptodate=$(core.package.is_uptodate "$manager" "$dependency" && echo true || echo false)

    tput cuu1
    tput el
    if $is_uptodate; then
      print.success "${BOLD}$dependency${NO_COLOR} ($local_version) is up-to-date"
    else
      print.info "${BOLD}$dependency${NO_COLOR} ($local_version) is not up-to-date, installing"
      local install_command
      install_command=$(core.package.install_command "$manager" "$dependency")
      print.info "Running ${BLUE}$install_command${NO_COLOR}"
    fi

    i=$((i + 1))
  done < <(core.csv.get "$manager")
}
