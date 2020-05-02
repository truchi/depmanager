#!/bin/bash

declare -A DEFAULT
DEFAULT[dir]="$HOME/.config/depmanager"
DEFAULT[apt]="apt.csv"
DEFAULT[yum]="yum.csv"
DEFAULT[pacman]="pacman.csv"
DEFAULT[node]="node.csv"
DEFAULT[rust]="rust.csv"

declare -A ARG
ARG[dir]=
ARG[apt]=
ARG[yum]=
ARG[pacman]=
ARG[node]=
ARG[rust]=

declare -A FOUND
FOUND[apt]=
FOUND[yum]=
FOUND[pacman]=
FOUND[node]=
FOUND[rust]=

declare -A DETECT
ARG[apt]=
ARG[yum]=
ARG[pacman]=
ARG[node]=
ARG[rust]=

COMMAND=
QUIET=false
YES=false

TYPES=(apt yum pacman node rust)

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

