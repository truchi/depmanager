# shellcheck shell=bash
# shellcheck source=../vars.sh
. ""

###############################################################
# Functions below cache corresponding functions in managers/ #
###############################################################

#
# Returns true if dependency $2 of manager $1 is installed, false otherwise
# With cache
#
core.package.is_installed() {
  local manager="$1"
  local package="$2"
  local write_cache="$3"

  if string.is_empty "$write_cache"; then
    write_cache=true
  fi

  helpers.cache \
    "core_package_is_installed__${manager}__${package}" \
    true \
    "$write_cache" \
    "managers.${manager}.package.is_installed $package"
}

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

