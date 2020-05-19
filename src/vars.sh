# shellcheck shell=bash

SYSTEM_MANAGERS=(apt)
NON_SYSTEM_MANAGERS=(node rust)
MANAGERS=("${SYSTEM_MANAGERS[@]}" "${NON_SYSTEM_MANAGERS[@]}")

SYSTEM_MANAGER=
COMMAND=
QUIET=false
YES=false
SIMULATE=false

declare -A __cache
declare -A CSVS
declare -A DEFAULTS
DEFAULTS[dir]="$HOME/.config/depmanager"
for manager in "${MANAGERS[@]}"; do
  DEFAULTS[$manager]="$manager.csv"
done

DEPMANAGER_CACHE_DIR="$HOME/.cache/depmanager"
FIFO="$DEPMANAGER_CACHE_DIR/fifo"
mkdir -p "$DEPMANAGER_CACHE_DIR"

if [ -t 1 ]; then
  NO_COLOR=$(tput sgr0)
  BOLD=$(tput bold)
  RED=$(tput setaf 1)
  GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3)
  BLUE=$(tput setaf 4)
  MAGENTA=$(tput setaf 5)
  CYAN=$(tput setaf 6)
  WHITE=$(tput setaf 7)
fi

