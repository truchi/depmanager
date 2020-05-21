# shellcheck shell=bash

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
    local is_uptodate
    if core.package.is_installed "$manager" "$dependency"; then
      installed=true
      core.package.local_version "$manager" "$dependency" > /dev/null
      local_version=$(core.package.local_version "$manager" "$dependency")
      is_uptodate=$([[ "$local_version" == "$remote_version" ]] && echo true || echo false)
    fi

    if ! $installed; then
      print.info "INSTALL!!!!! $dependency"
    elif $is_uptodate; then
      print.success "${BOLD}$dependency${NO_COLOR} is up-to-date ($local_version)"
    else
      print.warning "${BOLD}$dependency${NO_COLOR} is not up-to-date"
    fi

    i=$((i + 1))
  done < <(core.csv.get "$manager")
}
