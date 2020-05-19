# shellcheck shell=bash

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
