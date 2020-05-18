# shellcheck shell=bash
# shellcheck source=../vars.sh
. ""

#
# Sets `DIR` according to (in this precedence order):
# - env variable (relative to home)
# - default path
#
core.dir.resolve() {
  local dir=""

  # If env variable is defined
  if helpers.is_set "$DEPMANAGER_DIR"; then
    # Use user's dir
    dir="$DEPMANAGER_DIR"

    # Relative to home
    ! string.is_absolute "$dir" && dir="$HOME/$dir"
  else
    # Use default dir
    dir="${DEFAULTS[dir]}"
  fi

  CSVS[dir]="$dir"
}

