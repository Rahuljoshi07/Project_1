# Deployment notes

This is the exact flow I would use on a fresh Linux VPS with Docker installed.

## Prereqs on server

- Docker + Docker Compose plugin installed
- Firewall open for 80/443
- Folder for the app: `/opt/fastapi-stack`

## SSL approach

If I have a domain, I use Let's Encrypt with Certbot. If I do not have a domain yet, I generate a self-signed cert and still wire TLS so the stack behaves like production.

### Option A: real domain + Let's Encrypt (recommended)

```
# example for Ubuntu
sudo apt-get update
sudo apt-get install -y certbot
sudo certbot certonly --standalone -d YOUR_DOMAIN
sudo mkdir -p /opt/fastapi-stack/nginx/certs
sudo cp /etc/letsencrypt/live/YOUR_DOMAIN/fullchain.pem /opt/fastapi-stack/nginx/certs/
sudo cp /etc/letsencrypt/live/YOUR_DOMAIN/privkey.pem /opt/fastapi-stack/nginx/certs/
```

### Option B: self-signed cert (no domain yet)

```
mkdir -p nginx/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/certs/privkey.pem \
  -out nginx/certs/fullchain.pem \
  -subj "/CN=localhost"
```

## App environment

On the server, I create `.env` next to the compose file:

```
APP_ENV=production
LOG_LEVEL=INFO
DATABASE_URL=postgresql://appuser:apppass@db:5432/appdb
REDIS_URL=redis://redis:6379/0
```

## Deployment commands (manual)

```
docker compose -f docker-compose.prod.yml up -d --build
```

## GitHub Actions deploy

The workflow uses SSH + SCP. I set these secrets in GitHub:

- `SSH_HOST`
- `SSH_USER`
- `SSH_KEY`

When I push to `main`, it syncs to `/opt/fastapi-stack` and runs compose.

## Zero-downtime note

With Docker Compose, the closest thing to zero-downtime is to keep the old container running until the new one is healthy. The `healthcheck` endpoint makes it easy to verify readiness. For true zero-downtime, I would switch to blue/green or a reverse-proxy swap.

## Health check

```
curl -k https://YOUR_DOMAIN/health
```
