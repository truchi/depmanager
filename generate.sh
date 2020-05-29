#!/usr/bin/env bash

NO_COLOR=$(tput sgr0)
BOLD=$(tput bold)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
# YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
# MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
# WHITE=$(tput setaf 7)

function generate() {
  local manager="$1"

  if [[ -z "$manager" ]]; then
    echo "${BOLD}${BLUE}Usage:${NO_COLOR} ./generate my-manager
Generates ${CYAN}./src/managers/my-manager.sh${NO_COLOR}
"
  exit
  fi

  local file
  file=$(sed "s/__MANAGER__/$manager/g" < ./src/managers/template.sh)

  local out="./src/managers/${manager}.sh"
  echo "$file" > "$out"
  echo "${BOLD}${GREEN}✔${NO_COLOR} ${BLUE}Wrote ${CYAN}$out${NO_COLOR}"
  echo "${BLUE}Please edit this file following the instructions in the comments.${NO_COLOR}"
  echo "${RED}❤︎${NO_COLOR} ${BLUE}Thank you!${NO_COLOR}"
}

generate "$1"
