#!/bin/bash

table_print() {
  local pad=2
  local title=$1
  local headers=("${!2}")
  local column_count=$2
  local levels=("${!3}")
  local data=("${!4}")

  local has_title=$(string_is_empty "$title" && echo false || echo true)
  local has_headers=$(string_is_number $column_count && echo false || echo true)
  $has_headers && column_count=$(array_length headers[@])
  local row_count=$(array_length levels[@])

  local total_length
  local column_length=()
  for column_index in $(seq 0 $(($column_count - 1))); do
    local column=()
    table_get_column $column_index $column_count data[@]

    local max_length=$(string_length "${headers[$column_index]}")
    for cell in "${column[@]}"; do
      local cell_length=$(string_length "$cell")
      (( $cell_length > $max_length )) && max_length=$cell_length
    done

    (( $max_length == -1 )) && max_length=0
    max_length=$(($max_length + $pad))
    total_length=$(($total_length + $max_length))
    column_length[$column_index]=$max_length
  done

  $has_title && print_custom "  $(string_center "$title" $total_length)"
  total_length=$(($total_length - $pad))

  if $has_headers; then
    local header_row=""
    for column_index in $(seq 0 $(($column_count - 1))); do
      header=${headers[$column_index]}
      header_row="$header_row$(string_center "$header" "${column_length[$column_index]}")"
    done
    print_custom "  ${header_row[@]}"
  fi

  for row_index in $(seq 0 $(($row_count - 1))); do
    local message=""
    local level="${levels[$row_index]}"
    local row=()
    table_get_row $row_index $column_count data[@]

    for column_index in $(seq 0 $(($column_count - 1))); do
      local cell="${row[$column_index]}"
      message="$message$(string_pad_right "$cell" "${column_length[$column_index]}")"
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
