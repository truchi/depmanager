# shellcheck shell=bash

command.update() {
  local manager="$1"

  command.install "$manager"
}

