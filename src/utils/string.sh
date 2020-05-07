#!/bin/bash

string_raw_length() {
  local str="$1"
  echo ${#str}
}

string_length() {
  local str="$1"
  str=$(echo -e "$str" | sed "s/$(echo -e "\e")[^m]*m//g")
  echo ${#str}
}

string_is_number() {
  local arg=("${!1}") # May be an array
  local re='^[0-9]+$'
  [[ "${arg[@]}" =~ $re ]]
}

string_is_empty() {
  [[ -z "$1" ]]
}

string_pad_right() {
  local str="$1"
  local n="$2"
  printf "%-${n}s" "$str"
}
