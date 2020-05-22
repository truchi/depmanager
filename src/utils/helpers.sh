# shellcheck shell=bash
# shellcheck source=../vars.sh
. ""

#
# Returns true is $1 is set, false otherwise
#
helpers.is_set() {
  [[ -n "$1" ]]
}

#
# Returns true if file $1 exists, false otherwise
#
helpers.file_exists() {
  [[ -f "$1" ]]
}

#
# Returns true if url $1 exists, false otherwise
#
helpers.url_exists() {
  wget -q --spider "$1"
}

#
# Returns true if $1 is found on the system, false otherwise
#
helpers.command_exists() {
  command -v "$1" >/dev/null 2>&1
}

#
# Returns true is executed in a subshell, false otherwise
#
helpers.is_subshell() {
  [ "$$" -ne "$BASHPID" ]
}
#
# Removes blanks and duplicates from CSV (stdin)
#
helpers.sanitize_csv() {
  local lines=""
  local packages=()

  while read -ra line; do
    # Remove whitespaces
    line=$(sed 's/[[:space:]]*//g' <<< "${line[*]}")

    # Ignore if empty
    [[ $(string.length "$line") == 0 ]] && continue

    # Read first column
    local package
    IFS=, read -ra package <<< "$line"
    [[ $(string.length "$package") == 0 ]] && continue

    # Ignore if already there
    array.includes "$package" packages[@] && continue
    packages+=("$package")

    # Remove trailing comma
    line=$(sed 's/,$//g' <<< "$line")

    lines+="$line\n"
  done

  # Remove trailing newline
  lines=$(sed 's/\s$//g' <<< "$lines")

  echo "$lines"
}

