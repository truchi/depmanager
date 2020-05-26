# shellcheck shell=bash
# shellcheck source=../vars.sh
. ""

#
# Returns true if package $2 of manager $1 exists, false otherwise
#
core.package.exists() {
  local manager="$1"
  local package="$2"
  local version

  # Write cache
  core.package.version.remote "$manager" "$package" > /dev/null

  # Has version?
  [[ $(core.package.version.remote "$manager" "$package") != "$PACKAGE_NONE" ]]
}

#
# Returns true if package $2 of manager $1 is installed, false otherwise
#
core.package.is_installed() {
  local manager="$1"
  local package="$2"
  local version

  # Write cache
  core.package.version.local "$manager" "$package" > /dev/null

  # Has version?
  [[ $(core.package.version.local "$manager" "$package") != "$PACKAGE_NONE" ]]
}

#
# Returns true if package $2 of manager $1 exists, is installed and is up-to-date, false otherwise
#
core.package.is_uptodate() {
  local manager="$1"
  local package="$2"
  local local_version
  local remote_version

  # Not uptodate if doesn't exists
  if ! core.package.exists "$manager" "$package"; then
    false
    return
  fi

  # Not uptodate if not installed
  if ! core.package.is_installed "$manager" "$package"; then
    false
    return
  fi

  # Get versions
  local_version=$(core.package.version.local "$manager" "$package")
  remote_version=$(core.package.version.remote "$manager" "$package")

  # Compare versions
  [[ "$local_version" == "$remote_version" ]]
}

#
# Returns the local version of package $2 of manager $1
# With cache
#
core.package.version.local() {
  __core.package.version "$1" "$2" "$3" "local"
}

#
# Returns the remote version of package $2 of manager $1
# With cache
#
core.package.version.remote() {
  __core.package.version "$1" "$2" "$3" "remote"
}

#
# Returns the version (type $4) of package $2 of manager $1
# With cache
#
__core.package.version() {
  local manager="$1"
  local package="$2"
  local write_cache="$3"
  local version_type="$4"
  local cmd="managers.${manager}.package.version.${version_type}"

  string.is_empty "$write_cache" && write_cache=true
  cache "core_package_version_${version_type}__${manager}__${package}" true "$write_cache" "$cmd" "$package"
}

#
# Installs package $2 of manager $1
#
core.package.install() {
  local manager="$1"
  local package="$2"
  local quiet="$3"

  helpers.is_set "$quiet" || quiet=false
  $quiet && quiet=true

  local cmd
  "managers.${manager}.package.install_command" "$package" "$quiet"

  if $SIMULATE; then
    print.info "(Simulation) ${BLUE}${cmd[*]}${NO_COLOR}"
    return
  fi

  # local log_file="$DEPMANAGER_LOG_DIR/${manager}/${package}"
  # mkdir -p "$log_file"
  # touch "$log_file"

  local msg="${BOLD}Run ${BLUE}${cmd[*]}${NO_COLOR}${BOLD}?${NO_COLOR}"
  if print.confirm "$msg"; then
    ${cmd[*]}
  fi
}

core.package.install_or_update() {
  local manager="$1"
  local package="$2"

  print.info "${BOLD}$package${NO_COLOR} ..."

  local exists=false
  core.package.exists "$manager" "$package" && exists=true

  if ! $exists; then
    $QUIET || print.clear.line
    print.error "${BOLD}$package${NO_COLOR} does not exists"
    return
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
}

