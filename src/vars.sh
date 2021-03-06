# shellcheck shell=bash

VERSION="v0.0.1"

SYSTEM_MANAGERS=(apt)
NON_SYSTEM_MANAGERS=(npm)
MANAGERS=("${SYSTEM_MANAGERS[@]}" "${NON_SYSTEM_MANAGERS[@]}")

SYSTEM_MANAGER=
COMMAND=
QUIET=false
YES=false
SIMULATE=false

declare -A __cache
declare -A async_versions
declare -A CSVS
declare -A DEFAULTS
DEFAULTS[dir]="$HOME/.config/depmanager"
for manager in "${MANAGERS[@]}"; do
  DEFAULTS[$manager]="$manager.csv"
done

PACKAGE_NONE="<NONE>"
DEPMANAGER_TMP_DIR="/tmp/depmanager"
mkdir -p "$DEPMANAGER_TMP_DIR"

IN_TERMINAL=false
[ -t 1 ] && IN_TERMINAL=true
NO_COLOR=$(tput sgr0)
BOLD=$(tput bold)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)

