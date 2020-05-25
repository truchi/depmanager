# shellcheck shell=bash

#
# Returns true if apt is found on the system, false otherwise
#
managers.apt.exists() {
  helpers.command_exists apt && helpers.command_exists apt-cache && helpers.command_exists dpkg
}

#
# Returns apt version
#
managers.apt.version() {
  apt --version
}

#
# Returns the local version of package $1
#
managers.apt.package.version.local() {
  local dpkg_list
  dpkg_list=$(dpkg -l "$1" 2> /dev/null)

  # If dpkg errors, package is not installed
  if [[ $? != 0 ]]; then
    echo "$PACKAGE_NONE"
    return
  fi

  # Get relevant line
  dpkg_list=$(sed '6q;d' <<< "$dpkg_list")

  # If status is "n", package is not installed
  if [[ $(string.slice "$dpkg_list" 1 1) == "n" ]]; then
    echo "$PACKAGE_NONE"
    return
  fi

  # Extract version
  sed 's/\S*\s*\S*\s*\(\S*\).*/\1/' <<< "$dpkg_list"
}

#
# Returns the remote version of package $1
#
managers.apt.package.version.remote() {
  local policy
  policy=$(apt-cache policy "$1")

  # If apt returns nothing, package is not installed
  if [[ "$policy" == "" ]]; then
    echo "$PACKAGE_NONE"
    return
  fi

  # Extract version
  echo "$policy" | sed '3q;d' | sed 's/  Candidate: \(.*\).*/\1/'
}

#
# Returns the installation command for package $1
#
managers.apt.package.install_command() {
  local package="$1"
  local yes=""
  local quiet=""
  $QUIET && quiet="--quiet"
  $YES && yes="--yes"

  echo "sudo apt install $package $quiet $yes"
}

