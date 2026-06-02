# FastAPI Production Stack

I put together a minimal but production-ready FastAPI setup with everything I'd actually want on a real deployment:- Postgres, Redis, NGINX reverse proxy, monitoring, automated backups, security hardening, and zero-downtime deploys. The idea was to have a clean starting point that doesn't cut corners.

<p align="center">
  <img src="https://img.shields.io/badge/FastAPI-0.115-009688?style=for-the-badge&logo=fastapi&logoColor=white" alt="FastAPI" />
  <img src="https://img.shields.io/badge/PostgreSQL-16-336791?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL" />
  <img src="https://img.shields.io/badge/Redis-7-DC382D?style=for-the-badge&logo=redis&logoColor=white" alt="Redis" />
  <img src="https://img.shields.io/badge/NGINX-1.27-009639?style=for-the-badge&logo=nginx&logoColor=white" alt="NGINX" />
  <img src="https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker" />
  <img src="https://img.shields.io/badge/Prometheus-v2.54-E6522C?style=for-the-badge&logo=prometheus&logoColor=white" alt="Prometheus" />
  <img src="https://img.shields.io/badge/Grafana-11.2-F46800?style=for-the-badge&logo=grafana&logoColor=white" alt="Grafana" />
</p>


## Architecture

```mermaid
flowchart LR
  client[Client] -->|HTTPS| nginx[NGINX]
  nginx --> app[FastAPI]
  app --> db[(PostgreSQL)]
  app --> redis[(Redis)]
  prometheus[Prometheus] -.->|/metrics| app
  grafana[Grafana] --> prometheus
```

---

## Quick Start

```bash
git clone https://github.com/Rahuljoshi07/Project_1.git
cd Project_1
cp .env.example .env
docker compose up -d --build
```

Verify everything is running:-

```bash
curl http://localhost/
# {"message": "Hello from FastAPI"}

curl http://localhost/health
# {"ok": true, "postgres": {"ok": true}, "redis": {"ok": true}}
```

| Service | URL | Credentials |
|:---|:---|:---|
| FastAPI | http://localhost | none |
| Health Check | http://localhost/health | none |
| Prometheus | http://localhost:9090 | none |
| Grafana | http://localhost:3000 | `admin` / `admin` |

<img width="1598" height="887" alt="image" src="https://github.com/user-attachments/assets/abecfbad-ad96-4800-9eb3-f5baab70e29e" />

---

## Features

### 📈 Monitoring (Prometheus + Grafana)

I added [`prometheus-fastapi-instrumentator`](https://github.com/trallnag/prometheus-fastapi-instrumentator) so the app automatically exposes metrics at `/metrics`:- request counts by handler and status code, latency histograms, in-progress request tracking, and response size distribution.

Prometheus scrapes these every 15 seconds. Grafana comes pre-wired with Prometheus as the default datasource so there's nothing to configure after boot.

```
# HELP http_requests_total Total number of requests by method, status and handler.
# TYPE http_requests_total counter
http_requests_total{handler="/health",method="GET",status="2xx"} 42.0
```

> 📸 **Screenshot:- Grafana dashboard at `localhost:3000` with Prometheus datasource connected**
>
> ![Grafana dashboard](docs/images/grafana-dashboard.png)

> 📸 **Screenshot:- Prometheus targets page at `localhost:9090/targets` showing FastAPI being scraped**
>
> ![Prometheus targets](docs/images/prometheus-targets.png)

---

### ⚡ Zero-Downtime Blue-Green Deployments

The stack runs two app containers side by side (blue and green). Only one handles traffic at a time. When you deploy, the script builds the inactive one, waits for it to pass health checks, swaps NGINX's upstream config, reloads NGINX gracefully, and stops the old container. No dropped requests.

```
┌─────────────┐          ┌─────────────────┐
│   NGINX     │──────────│  App Blue       │  ← serving traffic
│  (upstream) │          │  (healthy)      │
└─────────────┘          ├─────────────────┤
                         │  App Green      │  ← idle / rebuilding
                         │  (standby)      │
                         └─────────────────┘
```

How the deploy script works:-

1. Detect which slot is currently active (blue or green)
2. Build and start the other slot
3. Poll `/health` until the new container reports healthy
4. Update `nginx/upstream.conf` to point at the new slot
5. Reload NGINX gracefully (`nginx -s reload`)
6. Stop the old container

```bash
sudo ./scripts/zero_downtime_deploy.sh
```

> 📸 **Screenshot:- Terminal output of `zero_downtime_deploy.sh` showing successful deployment**
>
> ![Zero downtime deploy](docs/images/zero-downtime-deploy.png)

---

### 🔒 Security

I tried to cover the basics that I'd actually do on a real VPS. Nothing fancy, just solid defaults that reduce the attack surface.

#### Firewall (UFW)

The script locks down the server to only what's needed:-

```bash
sudo ./scripts/setup_firewall.sh
```

What it does:-
- Sets default policy to **deny all incoming**
- Allows only **SSH (22)**, **HTTP (80)**, **HTTPS (443)**
- Explicitly blocks external access to Prometheus and Grafana ports
- Keeps outgoing traffic open for pulling images, updates, etc.

> 📸 **Screenshot:- Output of `ufw status verbose` showing active firewall rules**
>
> ![Firewall status](docs/images/firewall-status.png)

#### Fail2ban

Handles brute-force protection automatically:-

```bash
sudo ./scripts/setup_fail2ban.sh
```

| Jail | What it watches | Threshold | Ban duration |
|:---|:---|:---|:---|
| SSH | `/var/log/auth.log` | 5 failed logins in 10 min | 1 hour |
| NGINX HTTP auth | NGINX error logs | 3 failed auth attempts in 10 min | 1 hour |
| NGINX bot search | NGINX access logs | 5 exploit-path hits in 30 min | 24 hours |

You can check what's been blocked anytime with `fail2ban-client status`.

#### NGINX Security Headers

The production config (`nginx/prod.conf`) has these headers baked in:-

| Header | What it does |
|:---|:---|
| `Strict-Transport-Security` | Forces HTTPS for 2 years, including subdomains |
| `X-Frame-Options: DENY` | Blocks the site from being loaded in iframes |
| `X-Content-Type-Options: nosniff` | Prevents browsers from MIME-sniffing responses |
| `Referrer-Policy: no-referrer` | Stops referrer info leaking to other sites |

TLS is set to **1.2 and 1.3 only** with strong ciphers. No legacy SSL.

---

### ☁️ Cloudflare Integration

If you're running behind Cloudflare, NGINX sees Cloudflare's IP instead of your actual visitors. This script pulls the latest Cloudflare IP ranges and generates an NGINX config that restores the real client IP using the `CF-Connecting-IP` header:-

```bash
python scripts/cloudflare_ips.py
```

The generated `nginx/cloudflare.conf` gets included in the NGINX server block automatically. I'd recommend running this on a cron (monthly or so) to keep the IP list current.

---

### 💾 Automated Backups

```bash
# manual backup
./scripts/backup.sh
# creates /backups/appdb_20260602020000.sql.gz

# manual restore
./scripts/restore.sh /backups/appdb_20260602020000.sql.gz

# set up nightly cron (runs at 2am, keeps last 7 days)
sudo ./scripts/setup_backup_cron.sh
```

The backup script dumps Postgres, gzips it, and auto-prunes anything older than 7 days so you don't fill up the disk.

---

## Project Structure

```
.
├── app/
│   ├── main.py                    # FastAPI app with health checks and metrics
│   └── requirements.txt           # Python deps
│
├── nginx/
│   ├── dev.conf                   # NGINX config for local dev
│   ├── prod.conf                  # NGINX config with TLS + security headers
│   ├── upstream.conf              # dynamic upstream for blue-green switching
│   └── cloudflare.conf            # auto-generated cloudflare real-IP config
│
├── prometheus/
│   └── prometheus.yml             # scrape config
│
├── grafana/provisioning/
│   └── datasources/
│       └── datasource.yml         # auto-provisions Prometheus in Grafana
│
├── scripts/
│   ├── zero_downtime_deploy.sh    # blue-green deploy script
│   ├── setup_firewall.sh          # UFW setup
│   ├── setup_fail2ban.sh          # fail2ban setup
│   ├── cloudflare_ips.py          # fetch cloudflare IP ranges
│   ├── backup.sh                  # pg_dump + gzip + rotation
│   ├── restore.sh                 # restore from backup
│   └── setup_backup_cron.sh       # install nightly cron
│
├── docs/                          # detailed docs for each topic
├── .github/workflows/deploy.yml   # CI/CD pipeline
├── docker-compose.yml             # dev stack
├── docker-compose.prod.yml        # prod stack with TLS
├── Dockerfile                     # Python 3.11 slim
└── .env.example                   # env template
```

---

## Deployment

Full guide:- [docs/deployment.md](docs/deployment.md)

```bash
# 1. get SSL cert
sudo certbot certonly --standalone -d your-domain.com
sudo cp /etc/letsencrypt/live/your-domain.com/*.pem nginx/certs/

# 2. configure environment
cp .env.example .env
# edit .env, set APP_ENV=production

# 3. launch production stack
docker compose -f docker-compose.prod.yml up -d --build

# 4. verify
curl -k https://your-domain.com/health
```

> 📸 **Screenshot:- Production health check response from your domain**
>
> ![Production health check](docs/images/prod-health.png)

### CI/CD with GitHub Actions

Push to `main` and it auto-deploys via SSH. Set these secrets in your GitHub repo:-

| Secret | What to put |
|:---|:---|
| `SSH_HOST` | server IP or hostname |
| `SSH_USER` | SSH username |
| `SSH_KEY` | private SSH key |

---

## Docs

| Doc | What's in it |
|:---|:---|
| [architecture.md](docs/architecture.md) | system diagram |
| [deployment.md](docs/deployment.md) | full deployment walkthrough |
| [security.md](docs/security.md) | firewall, fail2ban, TLS notes |
| [monitoring.md](docs/monitoring.md) | Prometheus and Grafana setup |
| [backup.md](docs/backup.md) | backup and restore strategy |
| [logging.md](docs/logging.md) | log config and troubleshooting |

---

## Environment Variables

| Variable | Default | What it does |
|:---|:---|:---|
| `APP_ENV` | `local` | `local` or `production` |
| `LOG_LEVEL` | `INFO` | Python log level |
| `DATABASE_URL` | `postgresql://appuser:apppass@db:5432/appdb` | Postgres connection string |
| `REDIS_URL` | `redis://redis:6379/0` | Redis connection string |

---

## Contributing

1. Fork the repo
2. Create a branch (`git checkout -b feature/something`)
3. Commit your changes
4. Push and open a PR
