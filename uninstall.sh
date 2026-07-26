#!/bin/sh
# Session Save System v2 transactional uninstaller — adapters only, never records.
set -eu
REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SESSION_SAVE_OPERATION=uninstall exec "$REPO_DIR/install.sh" "$@"
