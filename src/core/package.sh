# shellcheck shell=bash
# shellcheck source=../vars.sh
. ""

#
# Returns true if dependency $2 of manager $1 exists, false otherwise
# With cache
#
core.package.exists() {
  local manager="$1"
  local package="$2"
  local version

  # Write cache
  core.package.remote_version "$manager" "$package" > /dev/null

  # Has version?
  [[ $(core.package.remote_version "$manager" "$package") != "$PACKAGE_NONE" ]]
}

#
# Returns true if dependency $2 of manager $1 is installed, false otherwise
# With cache
#
core.package.is_installed() {
  local manager="$1"
  local package="$2"
  local version

  # Write cache
  core.package.local_version "$manager" "$package" > /dev/null

  # Has version?
  [[ $(core.package.local_version "$manager" "$package") != "$PACKAGE_NONE" ]]
}

#
# Returns true if package $2 of manager $1 is up-to-date, false otherwise
# With cache
#
core.package.is_up_to_date() {
  local manager="$1"
  local package="$2"
  local local_version
  local remote_version

  # Write caches
  core.package.local_version "$manager" "$package" > /dev/null
  core.package.remote_version "$manager" "$package" > /dev/null

  # Get versions
  local_version=$(core.package.local_version "$manager" "$package")
  remote_version=$(core.package.remote_version "$manager" "$package")

  # Compare versions
  [[ "$local_version" == "$remote_version" ]]
}

###############################################################
# Functions below cache corresponding functions in managers/ #
###############################################################

#
# Returns the local version of dependency $2 of manager $1
# With cache
#
core.package.local_version() {
  local manager="$1"
  local package="$2"
  local write_cache="$3"

  if string.is_empty "$write_cache"; then
    write_cache=true
  fi

  helpers.cache \
    "core_package_local_version__${manager}__${package}" \
    true \
    "$write_cache" \
    "managers.${manager}.package.local_version $package"
}

#
# Returns the remote version of dependency $2 of manager $1
# With cache
#
core.package.remote_version() {
  local manager="$1"
  local package="$2"
  local write_cache="$3"

  if string.is_empty "$write_cache"; then
    write_cache=true
  fi

  helpers.cache \
    "core_package_remote_version__${manager}__${package}" \
    true \
    "$write_cache" \
    "managers.${manager}.package.remote_version $package"
}

