# Glide Updater

A robust auto-updater for Git repositories with systemd service integration.

## Features

- 🚀 Automatic updates from any Git repository
- ⚙️ Configurable update intervals and behaviors
- 🔒 Secure with proper user permissions
- 📝 Detailed logging
- 🔄 Systemd service for reliable background operation

## Prerequisites

- Linux-based system with systemd
- Bun runtime (will be installed automatically if not present)
- Git
- Node.js (installed automatically with Bun)

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/yourusername/glide-updater.git
   cd glide-updater
   ```

2. Run the installation script as root:
   ```bash
   sudo ./install.sh
   ```

The installer will:

- Install Bun if not present
- Install Node.js dependencies
- Set up the systemd service
- Create a default configuration file
- Start the updater service

## Configuration

Edit the configuration file at `~/.glide-updater-config.json` to customize:

```json
{
  "github": {
    "owner": "spire-panel",
    "repo": "glide",
    "branch": "main"
  },
  "paths": {
    "base": "/home/username/glide",
    "config": "/home/username/.glide-updater-config.json"
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
```

## Usage

### Start the service

```bash
sudo systemctl start glide-updater
```

### Stop the service

```bash
sudo systemctl stop glide-updater
```

### Check service status

```bash
systemctl status glide-updater
```

### View logs

```bash
journalctl -u glide-updater -f
```

## Manual Update Check

You can trigger an immediate update check by running:

```bash
bun src/index.ts
```

## Uninstallation

1. Stop and disable the service:

   ```bash
   sudo systemctl stop glide-updater
   sudo systemctl disable glide-updater
   ```

2. Remove the service file:

   ```bash
   sudo rm /etc/systemd/system/glide-updater.service
   ```

3. Reload systemd:

   ```bash
   sudo systemctl daemon-reload
   ```

4. (Optional) Remove configuration and data:
   ```bash
   rm -rf ~/.glide-updater-config.json ~/glide
   ```

## License

MIT

---

This project was created using `bun init` in bun v1.2.19. [Bun](https://bun.com) is a fast all-in-one JavaScript runtime.
