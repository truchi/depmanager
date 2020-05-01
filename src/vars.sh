#!/bin/bash

declare -A DEFAULT
DEFAULT[DIR]="$HOME/.config/depmanager"
DEFAULT[SYSTEM]="system.csv"
DEFAULT[NODE]="node.csv"
DEFAULT[RUST]="rust.csv"

declare -A ARG
ARG[DIR]=
ARG[SYSTEM]=
ARG[NODE]=
ARG[RUST]=

COMMAND=
QUIET=false
YES=false

TYPES=(SYSTEM NODE RUST)

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

