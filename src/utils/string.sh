# shellcheck shell=bash

string_is_empty() {
  [[ -z "$1" ]]
}

string_raw_length() {
  local str="$1"
  echo ${#str}
}

string_length() {
  local str
  str=$(string_strip_sequences "$1")
  echo ${#str}
}

string_strip_sequences() {
  echo -e "$1" | sed "s/$(echo -e "\e")[^m]*m//g"
}

string_is_number() {
  local re='^[0-9]+$'
  [[ "$1" =~ $re ]]
}

#
# Returns true if $@ starts with /, false otherwise
#
string_is_absolute() {
  [[ "$1" =~ / ]]
}

#
# Returns true if $@ starts with https?://, false otherwise
#
string_is_url() {
  [[ "$1" =~ https?:// ]]
}

#
# Retuns true if $1 contains $2, false otherwise
#
string_contains() {
  [[ "$1" == *"$2"* ]]
}

#
# Replaces $2 with $3 in $1
#
string_replace() {
  echo "${1//$2/$3}"
}

#
# Returns true if $1 equals $2, false otherwise
#
string_equals() {
  [[ "$1" == "$2" ]]
}

#
# Returns $1 from index $2 with length $3 (optional)
#
string_substring() {
  local string="$1"
  local offset="$2"
  local length="$3"

  ! is_set "$length" && length=$(string_length "$string")

  echo "${string:$offset:$length}"
}

string_center() {
  local str="$1"
  local width="$2"
  local length
  length=$(string_length "$str")

  if (( width < length )); then
    echo "$str"
  else
    local rest=$((width - length))
    local left_padding=$((rest / 2))
    local right_padding=$((width - left_padding))

    local left
    local right

    left=$(string_pad_right "" $left_padding)
    right=$(string_pad_right "$str" $right_padding)
    echo "$left$right"
  fi
}

string_pad_right() {
  local str="$1"
  local width="$2"
  local length
  length=$(string_length "$str")
  local raw_length
  raw_length=$(string_raw_length "$str")

  printf "%-$((width + raw_length - length))s" "$str"
}
