# Monitoring (bonus)

If I need quick, low-maintenance monitoring, I usually add one of these:

## Uptime-Kuma (simple)

- Runs as a container on the same host
- Checks `/health` and alerts on failures

## Prometheus + Grafana (more detailed)

- Add metrics to the app (Prometheus client)
- Scrape metrics and visualize in Grafana

For this small stack, Uptime-Kuma is usually enough.
