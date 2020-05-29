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
# Returns a list of installed packages
#
managers.npm.list.local() {
  npm list --global --depth 0 | grep "── "
}

#
# Returns the local version of package $1
#
managers.npm.package.version.local() {
  local list
  list=$(cache "managers_npm_list_local" true | grep "── $1@")

  # If npm returns "(empty)", package is not installed
  if [[ "$list" == "" ]]; then
    echo "$PACKAGE_NONE"
    return
  fi

  # Extract version
  sed 's/.*@//' <<< "$list"
}

#
# Returns the remote version of package $1
#
managers.npm.package.version.remote() {
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

#
# Returns the installation command for package $1
#
managers.npm.package.install_command() {
  local package="$1"
  local quiet="$2"

  cmd=("npm" "install" "$package" "--global" "--no-progress")
  $quiet && cmd+=("--quiet")
}

