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

  local cmd
  "managers.${manager}.package.install_command" "$package" "$QUIET"
  local msg="${BOLD}Run \`${YELLOW}${cmd[*]}${NO_COLOR}\`${BOLD}?${NO_COLOR}"

  if $SIMULATE; then
    print.confirm "$msg" "no"
    return
  fi

  if print.confirm "$msg"; then
    ${cmd[*]}
  fi
}

