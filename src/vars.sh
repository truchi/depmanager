#!/bin/bash

SYSTEM_TYPES=(apt yum pacman)
NON_SYSTEM_TYPES=(node rust)
TYPES=("${SYSTEM_TYPES[@]}" "${NON_SYSTEM_TYPES[@]}")

declare -A DEFAULT
DEFAULT[dir]="$HOME/.config/depmanager"
for type in "${TYPES[@]}"; do
  DEFAULT[$type]="$type.csv"
done

declare -A ARG
for type in "${TYPES[@]}"; do
  ARG[$type]=
done

declare -A BYPASS
for type in "${TYPES[@]}"; do
  BYPASS[$type]=false
done

declare -A FOUND
for type in "${TYPES[@]}"; do
  FOUND[$type]=false
done

declare -A DETECT
for type in "${TYPES[@]}"; do
  DETECT[$type]=false
done

declare -A PROCEED
for type in "${TYPES[@]}"; do
  PROCEED[$type]=false
done

COMMAND=
DIR=
QUIET=false
YES=false
SIMULATE=true # TODO should be false in prod

NO_COLOR=$(tput sgr0)
BOLD=$(tput bold)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)

CWD=$(pwd)

