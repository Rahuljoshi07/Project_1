# Security notes

This is a minimal baseline. The idea is to reduce obvious risk without turning the setup into a full platform project.

- NGINX TLS + HSTS enabled in [nginx/prod.conf](nginx/prod.conf)
- Container restart policy is `unless-stopped`
- Postgres is not exposed to the public network
- Redis is not exposed to the public network
- Sensitive config lives in `.env` and never in the repo

## Basic hardening steps I would apply

- Create a non-root SSH user on the server
- Disable password auth, use SSH keys only
- Enable UFW: allow 22, 80, 443 only
- Install fail2ban to block brute-force attempts

## Firewall example (UFW)

```
sudo ufw allow OpenSSH
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

## fail2ban quick setup

```
sudo apt-get install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```
