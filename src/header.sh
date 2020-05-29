#!/usr/bin/env bash
#
# depmanager v0.0.1
# https://github.com/truchi/depmanager
#
# Usage:
#   depmanager [-h|--version]
#   depmanager [-v|--help]
#   depmanager <cmd> [options] [flags]
#
# Description:
#   Manages your packages. (apt, npm)
#   Reads existing non-empty <manager>.csv files in $DEPMANAGER_DIR (defaults to $HOME/.config/depmanager).
#
# Commands:
#   I, interactive               Runs in interactive mode: asks for CSVs path/url, command and flags.
#   s, status                    Shows packages local and remote versions.
#   i, install                   Installs or updates packages.
#   u, update                    Updates installed packages.
#
# Options:
#   -a, --apt <path|url|ignore>  Path/Url of the apt CSV file. `ignore` to ignore apt.
#   -n, --npm <path|url|ignore>  Path/Url of the npm CSV file. `ignore` to ignore npm.
#
# Flags:
#   -Q, --quiet                  Prints errors only. Implies `--yes`.
#   -Y, --yes                    Answers `yes` to all prompts. Forced when stdout is not a terminal.
#   -S, --simulate               Answers `no` to installation prompts. Implies NOT `--quiet`.
#
# Links:
#   - Repository                 https://github.com/truchi/depmanager
