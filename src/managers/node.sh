# shellcheck shell=bash

#
# Returns true if node is found on the system, false otherwise
#
node_detect() {
  command_exists npm
}

#
# Returns node version
#
node_version() {
  node --version
}

#
# Returns true if dependency $1 is installed, false otherwise
#
node_is_installed() {
  local dependency=$1
  local list
  list=$(npm list --global --depth 0 "$dependency")

  echo "$list" | grep "── $dependency@" >/dev/null 2>&1
}

#
# Returns the local version of dependency $1
#
node_get_local_version() {
  npm list --global --depth 0 "$1" | sed '2q;d' | sed 's/└── .*@//'
}

#
# Returns the remote version of dependency $1
#
node_get_remote_version() {
  npm view "$1" version
}
