# shellcheck shell=bash
# shellcheck source=../vars.sh
. ""

#
# Creates fifo $1
#
cache.async.init() {
  local fifo="$1"

  # Creates new fifo
  [ -p "$fifo" ] && rm "$fifo"
  mknod "$fifo" p
}

#
# Write value $3 in fifo $1 for cache key $2
#
cache.async.write() {
  local fifo="$1"
  local key="$2"
  local value="$3"

  echo "$key,$value" > "$fifo"
}

#
# Creates and reads fifo named $1, $2 times, and writes data in cache
# Runs command $3 after read happens, with $... args
#
cache.async.listen() {
  local fifo="$1"
  local count="$2"
  local cmd="$3"
  local args=("$@")
  args=("${args[@]:3}")

  # Infinite loop (the only way to make this work properly?)
  local i=0
  while true; do
    local data
    local array

    # Read fifo
    read -r data
    ! helpers.is_set "$data" && continue

    # Read data and write in cache
    IFS=, read -r -a array <<< "$data"
    cache.set "${array[0]}" "${array[1]}" 0

    string.is_empty "$cmd" || $cmd "${args[@]}"

    i=$((i + 1))
    (( i == count )) && break
  done < "$fifo"
}

