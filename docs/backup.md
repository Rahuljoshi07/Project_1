# Backup and restore

I keep backups on the host and sync them to off-site storage (S3, Backblaze, or another server). I do not rely only on local disk.

## Backup script

The script is at `scripts/backup.sh`. It dumps Postgres and gzip-compresses it.

```
./scripts/backup.sh
```

## Restore

```
./scripts/restore.sh /path/to/backup.sql.gz
```

## Automated backups (cron example)

```
crontab -e
# nightly at 2am
0 2 * * * /opt/fastapi-stack/scripts/backup.sh
```

## Restart strategy

- `restart: unless-stopped` is set for all services
- After a host reboot, Docker restarts containers automatically
