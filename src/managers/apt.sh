#!/bin/bash

#
# Returns true if apt is found on the system, false otherwise
#
apt_detect() {
  if command_exists apt; then
    return 0
  else
    return 1
  fi
}
