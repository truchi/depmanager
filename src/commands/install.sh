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
    local package=${line[0]}
    print.info "${BOLD}$package${NO_COLOR} ..."

    local local_version
    local remote_version
    local exists
    local is_installed
    local is_uptodate

    core.package.version.remote "$manager" "$package" > /dev/null
    remote_version=$(core.package.version.remote "$manager" "$package")
    exists=$(core.package.exists "$manager" "$package" && echo true || echo false)

    if ! $exists; then
      print.clear.line
      print.warning "${BOLD}$package${NO_COLOR} do not exists"
      continue
    fi

    core.package.version.local "$manager" "$package" > /dev/null
    local_version=$(core.package.version.local "$manager" "$package")
    is_uptodate=$(core.package.is_uptodate "$manager" "$package" && echo true || echo false)

    print.clear.line
    if $is_uptodate; then
      print.success "${BOLD}$package${NO_COLOR} ($local_version) is up-to-date"
    else
      print.info "${BOLD}$package${NO_COLOR} ($local_version) is not up-to-date, installing"
      local install_command
      install_command=$(core.package.install_command "$manager" "$package")
      print.info "Running ${BLUE}$install_command${NO_COLOR}"
    fi

    i=$((i + 1))
  done < <(core.csv.get "$manager")
}
