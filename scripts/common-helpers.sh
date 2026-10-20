#!/bin/sh
# Common helper functions for Agent Up scripts
# Provides: die1, die2, warn
# Usage: source this file at the top of your script after set -eu

# Extract script name from $0 for error messages
_script_name() {
  basename "$0" | sed 's/\.sh$//'
}

# Exit 1 with FAIL prefix (validation/logical errors)
die1() {
  printf '%s: FAIL: %s\n' "$(_script_name)" "$1" >&2
  exit 1
}

# Exit 2 with plain prefix (usage/environment errors)
die2() {
  printf '%s: %s\n' "$(_script_name)" "$1" >&2
  exit 2
}

# Warning message (non-fatal)
warn() {
  printf '%s: WARNING: %s\n' "$(_script_name)" "$1" >&2
}
