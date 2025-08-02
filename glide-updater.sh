#!/bin/bash

# Default values
LOG_LEVEL="silent"
LOCKFILE="/tmp/glide-updater.lock"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --debug)
            LOG_LEVEL="info"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Check if another instance is running
if [ -f "$LOCKFILE" ]; then
    [ "$LOG_LEVEL" = "info" ] && echo "[$(date)] Updater already running."
    exit 0
fi

# Set up cleanup on exit
trap 'rm -f "$LOCKFILE"' EXIT

# Create lock file
touch "$LOCKFILE"

# Main loop
while true; do
    [ "$LOG_LEVEL" = "info" ] && echo "[$(date)] Checking for updates..."
    source ~/.bashrc
    BUN_PATH=$(which bun)
    # Run the updater with the appropriate log level
    env LOG_LEVEL="$LOG_LEVEL" "$BUN_PATH" "$SCRIPT_DIR/src/index.ts"
    
    [ "$LOG_LEVEL" = "info" ] && echo "[$(date)] Update check completed. Next check in 30 seconds..."
    sleep 30
done