#!/usr/bin/env sh
set -eu

if [ "$#" -gt 0 ]; then
  exec "$@"
fi

BACKUP_CRON="${BACKUP_CRON:-0 2 * * *}"
printf '%s /usr/local/bin/backup.sh\n' "$BACKUP_CRON" > /etc/crontabs/root

echo "Planification backup active: $BACKUP_CRON"
exec crond -f -l 2
