# shellcheck shell=bash

command.install() {
  local manager="$1"

  core.manager.install_or_update "$manager"
}

