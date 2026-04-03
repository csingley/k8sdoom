#!/bin/bash
# k8sdoom wrapper script
# XDG-compliant execution

XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DATA_DIR="$XDG_DATA_HOME/k8sdoom"
POLLER_PATH="$DATA_DIR/k8s-poll.sh"
WAD_PATH="$DATA_DIR/freedoom2.wad"

if [[ ! -f "$WAD_PATH" ]]; then
    echo "ERROR: Freedoom WAD not found at $WAD_PATH"
    echo "Please run 'make install' in the k8sdoom source directory."
    exit 1
fi

export PSDOOMPSCMD="$POLLER_PATH"
# Run the binary (assuming it's in the PATH as installed by make)
psdoom-ng -iwad "$WAD_PATH" "$@"
