#!/bin/sh
# Compatibility entry point; implementation lives under tests/.
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
exec sh "$SCRIPT_DIR/tests/test-runner.sh" "$@"
