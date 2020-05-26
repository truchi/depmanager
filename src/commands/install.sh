# shellcheck shell=bash

command.install() {
  local manager=$1

  print.info "${BOLD}${BLUE}$manager${NO_COLOR} (...)"

  local manager_version
  core.manager.version "$manager" > /dev/null
  manager_version=$(core.manager.version "$manager")

  $QUIET || print.clear.line
  print.info "${BOLD}${BLUE}$manager${NO_COLOR} ($manager_version)"

  local i=1
  IFS='
'
  for package in $(core.csv.get "$manager"); do
    IFS=' '
    print.info "${BOLD}$package${NO_COLOR} ..."

    local exists=false
    core.package.exists "$manager" "$package" && exists=true

    if ! $exists; then
      $QUIET || print.clear.line
      print.error "${BOLD}$package${NO_COLOR} does not exists"
      continue
    fi

    local local_version
    local is_installed=false
    local is_uptodate=false

    core.package.version.local "$manager" "$package" > /dev/null
    local_version=$(core.package.version.local "$manager" "$package")
    core.package.is_installed "$manager" "$package" && is_installed=true
    core.package.is_uptodate  "$manager" "$package" && is_uptodate=true

    $QUIET || print.clear.line

    if $is_installed; then
      if $is_uptodate; then
        print.success "${BOLD}$package${NO_COLOR} ($local_version) is up-to-date"
      else
        print.info "${BOLD}$package${NO_COLOR} ($local_version) is not up-to-date"
        core.package.install "$manager" "$package" "$QUIET"
      fi
    else
      print.info "${BOLD}$package${NO_COLOR} is not installed"
      core.package.install "$manager" "$package" "$QUIET"
    fi

    i=$((i + 1))
  done
}
