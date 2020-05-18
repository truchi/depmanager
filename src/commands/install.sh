# shellcheck shell=bash

run_install() {
  local manager=$1
  local file
  file=$(get_path "$manager")

  local i=1
  while IFS=, read -ra line; do
    local dependency=${line[0]}
    local installed=false
    local local_version="NONE"
    local remote_version
      remote_version=$("${manager}_get_remote_version" "$dependency")
    local up_to_date

    ! is_set "$remote_version" && remote_version="NONE"

    if "${manager}_is_installed" "$dependency"; then
      installed=true
      local_version=$("${manager}_get_local_version" "$dependency")
      up_to_date=$([[ "$local_version" == "$remote_version" ]] && echo true || echo false)
    fi

    if ! $installed; then
      print_info "INSTALL!!!!! $dependency"
    elif $up_to_date; then
      print_success "${BOLD}$dependency${NO_COLOR} is up-to-date ($local_version)"
    else
      print_warning "${BOLD}$dependency${NO_COLOR} is not up-to-date"
    fi

    i=$((i + 1))
  done < "$file"
}
