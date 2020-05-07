#!/bin/bash

array_length() {
  local array=("${!1}")
  echo "${#array[*]}"
}

