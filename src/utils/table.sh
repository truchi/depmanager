#!/bin/bash

table_print() {
  local pad=2
  local title=$1
  local headers=("${!2}")
  local levels=("${!3}")
  local data=("${!4}")

  local column_count=$(string_is_number headers[@] && echo "$headers" || echo $(array_length headers[@]))
  local row_count=$(array_length levels[@])

  local total_length
  local column_length=()
  for column_index in $(seq 0 $(($column_count - 1))); do
    local column=()
    table_get_column $column_index $column_count data[@]

    local length=-1
    for cell in "${column[@]}"; do
      local l=$(string_length "$cell")
      (( $l > $length )) && length=$l
    done

    column_length[$column_index]=$length
    total_length=$(($total_length + $length))
  done
  total_length=$(($total_length - $pad))

  local title_pad="$(string_pad_right "" $((($total_length - $(string_length "$title")) / 2)))"
  print_custom "  $title_pad$title"

  for row_index in $(seq 0 $(($row_count - 1))); do
    local message=""
    local level="${levels[$row_index]}"
    local row=()
    table_get_row $row_index $column_count data[@]

    for column_index in $(seq 0 $(($column_count - 1))); do
      local cell="${row[$column_index]}"
      local length=$(string_length "$cell")
      local raw_length=$(string_raw_length "$cell")

      message="$message$(string_pad_right "$cell" $(($pad + ${column_length[$column_index]} + $raw_length - $length)))"
    done

    print_${level} "$message"
  done
}

table_get_row() {
  local row_index=$1
  local column_count=$2
  local data=("${!3}")
  local first=$(($row_index * $column_count))
  local last=$((($row_index + 1) * $column_count - 1))

  local i=-1
  for cell in "${data[@]}"; do
    i=$(($i + 1))

    (( $i < $first )) && continue
    (( $i > $last  )) && break
    row+=("$cell")
  done
}

table_get_column() {
  local column_index=$1
  local column_count=$2
  local data=("${!3}")

  local i=-1
  for cell in "${data[@]}"; do
    i=$(($i + 1))

    (( $(($i % $column_count)) == $column_index )) \
      && column+=("$cell") \
      || continue
  done
}
