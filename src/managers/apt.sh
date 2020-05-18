# shellcheck shell=bash

#
# Returns true if apt is found on the system, false otherwise
#
apt_detect() {
  helpers.command_exists apt && helpers.command_exists apt-cache && helpers.command_exists dpkg
}

#
# Returns apt version
#
apt_version() {
  apt --version
}

#
# Returns true if dependency $1 is installed, false otherwise
#
apt_is_installed() {
  local dependency=$1
  local list
  list=$(apt list --installed "$dependency" 2>/dev/null | sed 's/Listing...//')

  echo "$list" | grep "^$dependency/" | grep '\[installed' >/dev/null 2>&1
}


#
# Returns the local version of dependency $1
#
apt_get_local_version() {
  apt-cache policy "$1" | sed '2q;d' | sed 's/  Installed: \(.*\).*/\1/'
}

#
# Returns the remote version of dependency $1
#
apt_get_remote_version() {
  apt-cache policy "$1" | sed '3q;d' | sed 's/  Candidate: \(.*\).*/\1/'
}
