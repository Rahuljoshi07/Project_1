#!/usr/bin/env sh
set -eu

echo "=========================================="
echo "Configuring UFW Firewall Hardening..."
echo "=========================================="

# Ensure UFW is installed
if ! command -v ufw >/dev/null 2>&1; then
    echo "UFW is not installed. Installing..."
    apt-get update && apt-get install -y ufw
fi

# Reset to defaults
ufw --force reset

# Set default policies (Deny all incoming, Allow all outgoing)
ufw default deny incoming
ufw default allow outgoing

# Allow standard web & SSH traffic
ufw allow 22/tcp comment 'Allow SSH'
ufw allow 80/tcp comment 'Allow HTTP'
ufw allow 443/tcp comment 'Allow HTTPS'

# Allow Docker Prometheus/Grafana only if accessed locally (by default, docker bypasses UFW unless configured)
# The safest practice is to map these ports only to localhost in compose, but if they are exposed, UFW will protect them on external interfaces.
ufw deny 9090 comment 'Block external Prometheus access'
ufw deny 3000 comment 'Block external Grafana access'

# Enable firewall
ufw --force enable

echo "Firewall successfully configured and enabled!"
ufw status verbose
