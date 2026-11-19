#!/usr/bin/env bash
set -euo pipefail

STAGING_DIR="${STAGING_DIR:-/staging}"
STATUS_DIR="${STATUS_DIR:-/status}"
LOCK_DIR="${LOCK_DIR:-/run/minvault/backup.lock}"
LOG_FILE="${LOG_FILE:-/var/log/minvault/backup.log}"
STARTED_AT="$(date +%s)"

now() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

mkdir "$LOCK_DIR" 2>/dev/null || {
  printf '%s backup déjà en cours\n' "$(now)" >&2
  exit 75
}
cleanup() { rmdir "$LOCK_DIR" 2>/dev/null || true; }
trap cleanup EXIT

mkdir -p "$STAGING_DIR" "$STATUS_DIR" "$(dirname "$LOG_FILE")"
exec >> >(tee -a "$LOG_FILE") 2>&1

write_status() {
  local success="$1"
  local finished duration
  finished="$(date +%s)"
  duration=$((finished - STARTED_AT))
  cat >"$STATUS_DIR/last_backup.prom" <<EOF
# HELP minvault_backup_success Whether the last backup completed successfully.
# TYPE minvault_backup_success gauge
minvault_backup_success $success
# HELP minvault_backup_timestamp_seconds Unix timestamp of the last backup attempt.
# TYPE minvault_backup_timestamp_seconds gauge
minvault_backup_timestamp_seconds $finished
# HELP minvault_backup_duration_seconds Duration of the last backup attempt.
# TYPE minvault_backup_duration_seconds gauge
minvault_backup_duration_seconds $duration
EOF
  printf '%s success=%s duration_seconds=%s\n' "$(now)" "$success" "$duration" >"$STATUS_DIR/last_backup.status"
}
trap 'write_status 0' ERR

: "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY est requis}"
: "${RESTIC_PASSWORD:?RESTIC_PASSWORD est requis}"
: "${BACKUP_AGENT_SECRET:?BACKUP_AGENT_SECRET est requis}"

printf '\n[%s] Début de la sauvegarde MinVault\n' "$(now)"
rm -rf "${STAGING_DIR:?}"/*

for bucket in documents media logs; do
  printf 'Synchronisation rclone du bucket %s\n' "$bucket"
  rclone sync "vault:$bucket" "$STAGING_DIR/$bucket" --fast-list --checksum --stats=10s
 done

if ! restic snapshots >/dev/null 2>&1; then
  printf 'Initialisation du dépôt restic\n'
  restic init
fi

restic backup "$STAGING_DIR" --tag minvault --host minvault
restic forget \
  --keep-daily "${RESTIC_KEEP_DAILY:-7}" \
  --keep-weekly "${RESTIC_KEEP_WEEKLY:-4}" \
  --keep-monthly "${RESTIC_KEEP_MONTHLY:-6}" \
  --prune
restic check

write_status 1
trap - ERR
printf '[%s] Sauvegarde MinVault terminée avec succès\n' "$(now)"
