#!/bin/bash

SYSTEM_MANAGERS=(apt yum pacman)
NON_SYSTEM_MANAGERS=(node rust)
MANAGERS=("${SYSTEM_MANAGERS[@]}" "${NON_SYSTEM_MANAGERS[@]}")

declare -A DEFAULT
DEFAULT[dir]="$HOME/.config/depmanager"
for manager in "${MANAGERS[@]}"; do
  DEFAULT[$manager]="$manager.csv"
done

declare -A ARG
for manager in "${MANAGERS[@]}"; do
  ARG[$manager]=
done

declare -A FOUND
for manager in "${MANAGERS[@]}"; do
  FOUND[$manager]=
done

declare -A DETECT
for manager in "${MANAGERS[@]}"; do
  DETECT[$manager]=
done

declare -A BYPASS
for manager in "${MANAGERS[@]}"; do
  BYPASS[$manager]=false
done

COMMAND=
DIR=
QUIET=false
YES=false
SIMULATE=false

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

