# Logging

I keep logs simple and centralized at first. Everything writes to stdout, which Docker captures and rotates.

## App logging

- Standard Python logging to stdout
- Uvicorn access logs

## NGINX logs

By default, NGINX logs to stdout in the container. If I need file logs, I add a volume and set `access_log` + `error_log`.

## View logs

```
docker compose logs -f app
```
