#!/bin/bash

#
# Returns true if apt is found on the system, false otherwise
#
apt_detect() {
  command_exists apt && command_exists apt-cache && command_exists dpkg
}

apt_version() {
  echo $(apt --version)
}

apt_status() {
  local file=$(get_path apt)

  while IFS=, read -r dependency; do
    echo dep:$dependency
    echo local:$(apt_get_local_version $dependency)
    echo remote:$(apt_get_remote_version $dependency)
  done < $file
}

apt_is_installed() {
  local dependency=$1
  local list=$(apt list --installed $dependency 2>/dev/null | sed 's/Listing...//')

  echo $list | grep "^$dependency/" | grep '\[installed' >/dev/null 2>&1
}

apt_get_local_version() {
  apt-cache policy $1 | sed '2q;d' | sed 's/  Installed: \(.*\).*/\1/'
}

apt_get_remote_version() {
  apt-cache policy $1 | sed '3q;d' | sed 's/  Candidate: \(.*\).*/\1/'
}
