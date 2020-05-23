# shellcheck shell=bash
# shellcheck source=../vars.sh
. ""

#
# Returns true if dependency $2 of manager $1 exists, false otherwise
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
# Returns true if dependency $2 of manager $1 is installed, false otherwise
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
# Return the install command for dependency $2 of manager $1
#
core.package.install_command() {
  local manager="$1"
  local package="$2"

  "managers.${manager}.package.install_command" "$package"
}

#
# Installs dependency $2 of manager $1
#
core.package.install() {
  local manager="$1"
  local package="$2"

  core.package.install_command "$manager" "$package"
}

#
# Returns the local version of dependency $2 of manager $1
# With cache
#
core.package.version.local() {
  local manager="$1"
  local package="$2"
  local write_cache="$3"

  local cmd="managers.${manager}.package.version.local $package"
  string.is_empty "$write_cache" && write_cache=true
  cache "core_package_version_local__${manager}__${package}" true "$write_cache" "$cmd"
}

#
# Asynchronously writes the local version of dependency $3 of manager $2 in cache
# Async cache MUST listen to fifo $1
#
core.package.async.version.local() {
  local fifo="$1"
  local manager="$2"
  local package="$3"

  cache.async.write "$fifo" "core_package_version_local__${manager}__${package}" "$("core.package.version.local" "$manager" "$package" false)"
}

#
# Returns the remote version of dependency $2 of manager $1
# With cache
#
core.package.version.remote() {
  local manager="$1"
  local package="$2"
  local write_cache="$3"

  local cmd="managers.${manager}.package.version.remote $package"
  string.is_empty "$write_cache" && write_cache=true
  cache "core_package_version_remote__${manager}__${package}" true "$write_cache" "$cmd"
}

#
# Asynchronously writes the remote version of dependency $3 of manager $2 in cache
# Async cache MUST listen to fifo $1
#
core.package.async.version.remote() {
  local fifo="$1"
  local manager="$2"
  local package="$3"

  cache.async.write "$fifo" "core_package_version_remote__${manager}__${package}" "$("core.package.version.remote" "$manager" "$package" false)"
}

