# shellcheck shell=bash

#
# Returns true if npm is found on the system, false otherwise
#
managers.npm.exists() {
  helpers.command_exists npm
}

#
# Returns npm version
#
managers.npm.version() {
  npm --version
}

#
# Returns true if dependency $1 is installed, false otherwise
#
managers.npm.package.is_installed() {
  local dependency=$1
  local list
  list=$(npm list --global --depth 0 "$dependency")

  echo "$list" | grep "── $dependency@" >/dev/null 2>&1
}

#
# Returns the local version of dependency $1
#
managers.npm.package.local_version() {
  local npm_list
  npm_list=$(npm list --global --depth 0 "$1" | sed '2q;d' | sed 's/└── //')

  # If npm returns "(empty)", package is not installed
  if [[ "$npm_list" == "(empty)" ]]; then
    echo "$PACKAGE_NONE"
    return
  fi

  # Extract version
  sed 's/.*@//' <<< "$npm_list"
}

#
# Returns the remote version of dependency $1
#
managers.npm.package.remote_version() {
  local version
  version=$(npm view "$1" version 2> /dev/null)

  # If npm errors, package is not installed
  if [[ $? != 0 ]]; then
    echo "$PACKAGE_NONE"
    return
  fi

  # Return version
  echo "$version"
}
