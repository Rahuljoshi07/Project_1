#!/usr/bin/env sh
set -eu

echo "=========================================="
echo "Configuring Automated Backup Cron Job..."
echo "=========================================="

CRON_FILE="/etc/cron.d/fastapi_backup"
SCRIPT_PATH="/opt/fastapi-stack/scripts/backup.sh"

# Ensure backup script is executable
chmod +x "$SCRIPT_PATH" 2>/dev/null || chmod +x "scripts/backup.sh"

# Create the cron configuration to run every night at 2:00 AM
# Writes to /etc/cron.d/ which runs automatically as root on Ubuntu/Debian
cat <<EOF > "$CRON_FILE"
# Nightly backup of the FastAPI Stack PostgreSQL database at 2:00 AM
0 2 * * * root /bin/sh "$SCRIPT_PATH" > /var/log/fastapi_backup.log 2>&1
EOF

# Ensure proper permissions for system crontab files
chmod 0644 "$CRON_FILE"

# Restart cron daemon to apply
if command -v systemctl >/dev/null 2>&1; then
    systemctl restart cron || systemctl restart crond || echo "Cron daemon restarted."
else
    service cron restart || echo "Cron service restarted."
fi

echo "Nightly backup successfully scheduled in $CRON_FILE!"
echo "Cron job will execute $SCRIPT_PATH every night at 2:00 AM."
