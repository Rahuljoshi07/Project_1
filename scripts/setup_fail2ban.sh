#!/usr/bin/env sh
set -eu

echo "=========================================="
echo "Configuring Fail2ban Hardening..."
echo "=========================================="

# Ensure fail2ban is installed
if ! command -v fail2ban-client >/dev/null 2>&1; then
    echo "Fail2ban is not installed. Installing..."
    apt-get update && apt-get install -y fail2ban
fi

# Copy baseline local config
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Enable standard sshd jail
cat <<EOF > /etc/fail2ban/jail.d/sshd.local
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 1h
findtime = 10m
EOF

# Create Nginx Bad Request / Brute Force filter & jail if Nginx logs are mounted
# In production, Docker container logs or mounted volumes are stored under /var/log/nginx/ or /var/lib/docker/containers/
cat <<EOF > /etc/fail2ban/jail.d/nginx-limit.local
[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /opt/fastapi-stack/nginx/logs/error.log
maxretry = 3
bantime = 1h
findtime = 10m

[nginx-botsearch]
enabled = true
filter = nginx-botsearch
port = http,https
logpath = /opt/fastapi-stack/nginx/logs/access.log
maxretry = 5
bantime = 1d
findtime = 30m
EOF

# Restart Fail2ban to load new jails
systemctl restart fail2ban

echo "Fail2ban successfully configured and restarted!"
fail2ban-client status
