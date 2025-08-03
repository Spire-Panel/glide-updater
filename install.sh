#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
DEBUG_MODE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug)
            DEBUG_MODE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

echo -e "${YELLOW}🚀 Starting Glide Updater installation...${NC}"
[ "$DEBUG_MODE" = true ] && echo -e "${YELLOW}🔧 Debug mode enabled${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}⚠️  Please run as root or with sudo${NC}"
    exit 1
fi

if [ ! -f "glide-updater.sh" ]; then
    git clone https://github.com/spire-panel/glide-updater.git ./glide-updater
fi

while [ ! -d "./glide-updater" ]; do
    sleep 1
done

cd ./glide-updater

# Check for Bun
if ! command -v bun &> /dev/null; then
    echo -e "${YELLOW}⚠️  Bun is not installed. Installing Bun...${NC}"
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
    echo 'export PATH="$HOME/.bun/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
fi

# Install dependencies
echo -e "${GREEN}📦 Installing dependencies...${NC}"
bun install

# Make scripts executable
echo -e "${GREEN}🔧 Setting up scripts...${NC}"
chmod +x glide-updater.sh
chmod +x install.sh

# Install systemd service
echo -e "${GREEN}🚀 Installing systemd service...${NC}"
SERVICE_FILE="/etc/systemd/system/glide-updater.service"

# Create the service file with debug option if enabled
cat > $SERVICE_FILE <<EOL
[Unit]
Description=Glide Updater Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$(pwd)
$(if [ "$DEBUG_MODE" = true ]; then
    echo "ExecStart=$(pwd)/glide-updater.sh --debug"
else
    echo "ExecStart=$(pwd)/glide-updater.sh"
    echo "# Uncomment the line below to enable debug logging"
    echo "#ExecStart=$(pwd)/glide-updater.sh --debug"
fi)
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd and enable service
echo -e "${GREEN}🔄 Reloading systemd daemon...${NC}"
systemctl daemon-reload
systemctl enable --now glide-updater.service

# Create default config if it doesn't exist
if [ ! -f "$HOME/.glide-updater-config.json" ]; then
    echo -e "${GREEN}📝 Creating default configuration...${NC}"
    cat > "$HOME/.glide-updater-config.json" <<EOL
{
  "github": {
    "owner": "spire-panel",
    "repo": "glide",
    "branch": "main"
  },
  "paths": {
    "base": "$HOME/glide",
    "config": "$HOME/.glide-updater-config.json"
  },
  "logging": {
    "level": "info"
  },
  "service": {
    "name": "glide-updater.service",
    "autoRestart": true
  },
  "update": {
    "checkInterval": 30,
    "autoInstall": true
  }
}
EOL
fi

# Create the target directory if it doesn't exist
if [ ! -d "$HOME/glide" ]; then
    echo -e "${GREEN}📂 Creating Glide directory...${NC}"
    mkdir -p "$HOME/glide"
    chown -R $SUDO_USER:$SUDO_USER "$HOME/glide"
fi

# Set proper permissions
echo -e "${GREEN}🔒 Setting permissions...${NC}"
chown -R $SUDO_USER:$SUDO_USER .
chmod 600 "$HOME/.glide-updater-config.json"

# Start the service
echo -e "${GREEN}🚀 Starting Glide Updater service...${NC}"
systemctl restart glide-updater.service

echo -e "${GREEN}✅ Installation complete!${NC}"
echo -e "${YELLOW}📝 Configuration file: $HOME/.glide-updater-config.json${NC}"
echo -e "${YELLOW}📋 Service status: systemctl status glide-updater${NC}"
echo -e "${YELLOW}📜 View logs: journalctl -u glide-updater -f${NC}"

exit 0
