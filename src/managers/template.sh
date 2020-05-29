# shellcheck shell=bash

################################################################################
# This file is a template to help you support more managers.
# Run `./generate my-manager` and edit ./src/managers/my-manager.sh
# You will also have to add the manager name in
# either SYSTEM_MANAGERS or NON_SYSTEM_MANAGERS in ./src/vars.sh
################################################################################

################################################################################
# A manager has 5 public mandatory functions:
# - exists                  (checks if the manager is installed)
# - version                 (gets the manager's version)
# - package.version.local   (gets a package's local version)
# - package.version.remote  (gets a package's remote version)
# - package.install_command (returns the install command for a package)
#
# These are the only functions you are REQUIRED to implement.
# See below for example implementations and details.
# You are welcome to add your own private functions.
#
# Please:
# - Prefix your private functions name with "__managers.__MANAGER__."
# - Comment your code
# - Do not write comments at the end of lines (a minimifier thing...)
# - Remove unused comments
#
# Thanks for your help.
################################################################################

#
# Returns true if __MANAGER__ is found on the system, false otherwise
#
managers.__MANAGER__.exists() {
  # Check here for the existence of the manager command,
  # and all commands you will use in the functions below
  # ===

  helpers.command_exists __MANAGER__
}

#
# Returns __MANAGER__ version
#
managers.__MANAGER__.version() {
  # Returns, ...humm, the manager's version
  # ===

  __MANAGER__ --version
}

#
# Returns a list of installed packages
#
managers.__MANAGER__.list.local() {
  # This function is optional
  # Use it if you can get a list of all installed packages in a simple call
  # The return value will be cached,
  # for use in `managers.__MANAGER__.package.version.local` (see below)
  # ===

  __MANAGER__ list
}

#
# Returns the local version of package $1
#
managers.__MANAGER__.package.version.local() {
  # Here we need to return the local version of $1
  # Below is an example implementation using
  # the optional function `managers.__MANAGER__.list.local` above
  # If you cannot use the above optional function, chances are the implementation
  # of this function will be similar anyway.
  # Remember:
  # This function can be call asynchronously
  # It MUST return "$PACKAGE_NONE" if the package is not installed
  # ===

  # Read appropriate line in local list (from cache)
  local line
  line=$(cache "managers___MANAGER___list_local" true | grep "$1")

  # If no line is found, package is not installed
  if [[ "$line" == "" ]]; then
    echo "$PACKAGE_NONE"
    return
  fi

  # Extract version
  sed '<SOMETHING HERE>' <<< "$line"
}

#
# Returns the remote version of package $1
#
managers.__MANAGER__.package.version.remote() {
  # Here we need to return the remote version of $1
  # Remember:
  # This function can be call asynchronously
  # It MUST return "$PACKAGE_NONE" if the package does not exist
  # ===

  local version
  version=$(__MANAGER__ remote-version "$1" 2> /dev/null)

  # If __MANAGER__ errors, package is not installed
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
managers.__MANAGER__.package.install_command() {
  # This function returns the command to run to install package $1
  # You MUST respect boolean argument $2 quiet, if the manager supports it.
  # Please use long command names & flags for readability
  # ===

  local package="$1"
  local quiet="$2"

  cmd=("__MANAGER__" "install" "$package")
  $quiet && cmd+=("--quiet")
}

