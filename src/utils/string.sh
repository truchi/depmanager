#!/bin/bash

string_is_empty() {
  [[ -z "$@" ]]
}

string_raw_length() {
  local str="$@"
  echo ${#str}
}

string_length() {
  local str=$(string_strip_sequences "$@")
  echo ${#str}
}

string_strip_sequences() {
  echo -e "$@" | sed "s/$(echo -e "\e")[^m]*m//g"
}

string_is_number() {
  local re='^[0-9]+$'
  [[ $@ =~ $re ]]
}

#
# Returns true if $@ starts with /, false otherwise
#
string_is_absolute() {
  [[ "$@" =~ / ]]
}

#
# Returns true if $@ starts with https?://, false otherwise
#
string_is_url() {
  [[ "$@" =~ https?:// ]]
}

string_center() {
  local str="$1"
  local width="$2"
  local length=$(string_length "$str")

  if (( $width < $length )); then
    echo $str
  else
    local left_padding=$((($width - $length) / 2))
    local right_padding=$(($width - $left_padding))

    local left=$(string_pad_right "" $left_padding)
    local right=$(string_pad_right "$str" $right_padding)
    echo "$left$right"
  fi
}

string_pad_right() {
  local str="$1"
  local width="$2"
  local length=$(string_length "$str")
  local raw_length=$(string_raw_length "$str")

  printf "%-$(($width + $raw_length - $length))s" "$str"
}
