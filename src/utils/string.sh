#!/bin/bash

string_is_empty() {
  [[ -z "$1" ]]
}

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
  local re='^[0-9]+$'
  [[ $1 =~ $re ]]
}

string_center() {
  local str="$1"
  local width="$2"
  local length=$(string_length "$str")
  local left_padding=$((($width - $length) / 2))
  local right_padding=$(($width - $left_padding))

  local left=$(string_pad_right "" $left_padding)
  local right=$(string_pad_right "$str" $right_padding)
  echo "$left$right"
}

string_pad_right() {
  local str="$1"
  local width="$2"
  local length=$(string_length "$str")
  local raw_length=$(string_raw_length "$str")

  printf "%-$(($width + $raw_length - $length))s" "$str"
}
