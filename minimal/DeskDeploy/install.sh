#!/bin/bash
# install.sh — install the OTC Proof Trading Desk
# Run as root: sudo ./install.sh

set -e

REPO_ROOT="/mnt/data1/time-2026/09-september/18/lean-worker"
DESK_DIR="$REPO_ROOT/minimal/DeskServer"
SERVICE_FILE="/etc/systemd/system/otc-desk.service"

echo "=== Installing OTC Proof Trading Desk ==="

# 1. Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo)"
    exit 1
fi

# 2. Create the otc-desk system user if it doesn't exist
if ! id "otc-desk" &>/dev/null; then
    echo "Creating otc-desk user..."
    useradd --system --no-create-home --shell /usr/sbin/nologin otc-desk
fi

# 3. Create the StateDirectory
mkdir -p /var/lib/otc-desk
chown otc-desk:otc-desk /var/lib/otc-desk
chmod 700 /var/lib/otc-desk

# 4. Set proper permissions on the repo (read-only for the service)
chown -R root:root "$REPO_ROOT"
chmod -R 755 "$REPO_ROOT"

# 5. Set permissions on DeskServer (writable by otc-desk for logs)
chown -R otc-desk:otc-desk "$DESK_DIR"
chmod -R 755 "$DESK_DIR"

# 6. Install the systemd service
echo "Installing systemd service..."
cp "$REPO_ROOT/minimal/DeskDeploy/otc-desk.service" "$SERVICE_FILE"
systemctl daemon-reload

# 7. Enable and start the service
echo "Enabling otc-desk service..."
systemctl enable otc-desk

# 8. Configure nginx (optional - skip if nginx not installed)
if command -v nginx &>/dev/null; then
    echo "Configuring nginx..."
    if [ -d /etc/nginx/sites-available ]; then
        cp "$REPO_ROOT/minimal/DeskDeploy/nginx.conf" /etc/nginx/sites-available/otc-desk.conf
        ln -sf /etc/nginx/sites-available/otc-desk.conf /etc/nginx/sites-enabled/otc-desk.conf
        nginx -t && systemctl reload nginx
    fi
fi

echo "=== Installation Complete ==="
echo ""
echo "To start the desk: systemctl start otc-desk"
echo "To check status:   systemctl status otc-desk"
echo "To view logs:      journalctl -u otc-desk -f"
echo ""
echo "The desk should be available at https://desk.example.com"