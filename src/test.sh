#!/usr/bin/env bash

avant test2

# shellcheck source=test2.sh
. ""

some stuff
some stuff 2
apres test2
avant test3

# shellcheck source=test3.sh
. ""

apres test3
avant test3

# shellcheck source=test3.sh
. ""

apres test3
some other stuff
some other stuff 2

PATHS["apt"]=12

