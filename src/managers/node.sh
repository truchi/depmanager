# shellcheck shell=bash

#
# Returns true if node is found on the system, false otherwise
#
managers.node.exists() {
  helpers.command_exists npm
}

#
# Returns node version
#
managers.node.version() {
  node --version
}

#
# Returns true if dependency $1 is installed, false otherwise
#
managers.node.package.is_installed() {
  local dependency=$1
  local list
  list=$(npm list --global --depth 0 "$dependency")

  echo "$list" | grep "── $dependency@" >/dev/null 2>&1
}

#
# Returns the local version of dependency $1
#
managers.node.package.local_version() {
  npm list --global --depth 0 "$1" | sed '2q;d' | sed 's/└── .*@//'
}

#
# Returns the remote version of dependency $1
#
managers.node.package.remote_version() {
  npm view "$1" version
}
