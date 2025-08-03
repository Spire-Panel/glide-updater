#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
PURGE_DATA=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --purge-data)
            PURGE_DATA=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

echo -e "${YELLOW}🚀 Starting Glide Updater uninstallation...${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}⚠️  Please run as root or with sudo${NC}"
    exit 1
fi

# Stop and disable service if it exists
if systemctl is-active --quiet glide-updater.service 2>/dev/null; then
    echo -e "${YELLOW}🛑 Stopping Glide Updater service...${NC}"
    systemctl stop glide-updater.service
    systemctl disable glide-updater.service
fi

# Remove systemd service file
SERVICE_FILE="/etc/systemd/system/glide-updater.service"
if [ -f "$SERVICE_FILE" ]; then
    echo -e "${YELLOW}🗑️  Removing systemd service file...${NC}"
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    systemctl reset-failed
fi

# Remove config file
CONFIG_FILE="$HOME/.glide-updater-config.json"
if [ -f "$CONFIG_FILE" ]; then
    if [ "$PURGE_DATA" = true ]; then
        echo -e "${YELLOW}🗑️  Removing configuration file...${NC}"
        rm -f "$CONFIG_FILE"
    else
        echo -e "${YELLOW}ℹ️  Keeping configuration file: $CONFIG_FILE${NC}"
        echo -e "${YELLOW}   Use --purge-data to remove this file${NC}"
    fi
fi

# Remove Glide directory if purge-data is set
GLIDE_DIR="$HOME/glide"
if [ "$PURGE_DATA" = true ] && [ -d "$GLIDE_DIR" ]; then
    echo -e "${YELLOW}🗑️  Removing Glide directory...${NC}"
    rm -rf "$GLIDE_DIR"
fi

echo -e "${RED}✅ Uninstallation complete!${NC}"
echo -e "${YELLOW}Note: The Glide Updater source files in $(pwd) have been kept.${NC}"
echo -e "${YELLOW}      Remove them manually if you don't need them anymore.${NC}"

exit 0
