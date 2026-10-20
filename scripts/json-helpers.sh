#!/bin/sh
# JSON parsing helper functions for Agent Up scripts
# Provides: json_extract_string, json_extract_number, json_validate_row
# Usage: source this file after common-helpers.sh

# json_extract_string: Extract string value from JSON line
# Args: $1=json_line, $2=key
# Returns: extracted value (empty if not found)
# Note: Handles simple string fields only, no nested objects or arrays
json_extract_string() {
  _json_line="$1"
  _json_key="$2"

  printf '%s\n' "$_json_line" | awk -v key="$_json_key" '
    function jval(line, k,    i, rest, j) {
      i = index(line, "\"" k "\": \"")
      if (i == 0) return ""
      rest = substr(line, i + length(k) + 5)
      j = index(rest, "\"")
      if (j == 0) return ""
      return substr(rest, 1, j - 1)
    }
    { print jval($0, key) }
  '
}

# json_extract_number: Extract numeric value from JSON line
# Args: $1=json_line, $2=key
# Returns: extracted value (empty if not found)
# Note: Matches pattern: "key": value (no quotes around value)
json_extract_number() {
  _json_line="$1"
  _json_key="$2"

  printf '%s\n' "$_json_line" | awk -v key="$_json_key" '
    function jnum(line, k,    i, rest, j, val) {
      i = index(line, "\"" k "\": ")
      if (i == 0) return ""
      rest = substr(line, i + length(k) + 4)
      # Match digits, optional decimal point and more digits
      match(rest, /^[0-9]+(\.[0-9]+)?/)
      if (RSTART == 0) return ""
      return substr(rest, RSTART, RLENGTH)
    }
    { print jnum($0, key) }
  '
}

# json_validate_row: Validate JSON line has required fields
# Args: $1=json_line, $2=field1, $3=field2, ... (space-separated required fields)
# Returns: 0 if all fields present and non-empty, 1 otherwise
# Side effect: Prints error to stderr if validation fails
json_validate_row() {
  _json_line="$1"
  shift
  _required_fields="$*"

  for _field in $_required_fields; do
    _value=$(json_extract_string "$_json_line" "$_field")
    if [ -z "$_value" ]; then
      printf 'json_validate_row: FAIL: 条目缺必备字段 "%s": %s\n' "$_field" "$_json_line" >&2
      return 1
    fi
  done
  return 0
}
