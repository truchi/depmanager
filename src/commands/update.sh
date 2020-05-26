# shellcheck shell=bash

command.update() {
  local manager="$1"

  core.manager.install_or_update "$manager"
}

