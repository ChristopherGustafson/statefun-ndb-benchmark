#!/bin/bash

filename="$1"

file_size="$(stat --format=%s "$filename")"
trim_count="$(tail -n1 "$filename" | wc -c)"
end_position="$(echo "$file_size - $trim_count" | bc)"

dd if=/dev/null of="$filename" bs=1 seek="$end_position"