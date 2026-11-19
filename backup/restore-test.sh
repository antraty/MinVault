#!/usr/bin/env bash
set -euo pipefail

TEST_ROOT="${TEST_ROOT:-/tmp/minvault-restore-test}"
PREFIX=".minvault-restore-test"
WITNESS_DIR="$TEST_ROOT/witness"
RESTORE_DIR="$TEST_ROOT/restored"
STATUS_DIR="${STATUS_DIR:-/status}"
TEST_RCLONE_CONFIG="$TEST_ROOT/rclone-test.conf"
TEST_ENDPOINT="${TEST_ENDPOINT:-http://minio1:9000}"
STARTED_AT="$(date +%s)"
WITNESS_CREATED_AT=""
RESULT="FAIL"
RTO_SECONDS=""
RPO_SECONDS=""

write_status() {
  local finished_at
  finished_at="$(date +%s)"
  if [[ -z "$RTO_SECONDS" ]]; then
    RTO_SECONDS=$((finished_at - STARTED_AT))
  fi
  if [[ -z "$RPO_SECONDS" ]]; then
    RPO_SECONDS="unknown"
  fi
  mkdir -p "$STATUS_DIR"
  printf '%s result=%s rto_seconds=%s rpo_seconds=%s\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$RESULT" "$RTO_SECONDS" "$RPO_SECONDS" \
    > "$STATUS_DIR/restore-test.status"
  if [[ "$RESULT" != "PASS" ]]; then
    printf 'RESULT: FAIL\n' >&2
  fi
}

cleanup() {
  write_status
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

: "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY est requis}"
: "${RESTIC_PASSWORD:?RESTIC_PASSWORD est requis}"
: "${BACKUP_AGENT_SECRET:?BACKUP_AGENT_SECRET est requis}"
: "${APP_DOCS_SECRET:?APP_DOCS_SECRET est requis pour créer les témoins}"

mkdir -p "$WITNESS_DIR" "$RESTORE_DIR" "$STATUS_DIR"
cat > "$TEST_RCLONE_CONFIG" <<EOF
[test]
type = s3
provider = Minio
env_auth = false
access_key_id = app-docs
secret_access_key = ${APP_DOCS_SECRET}
endpoint = ${TEST_ENDPOINT}
region = us-east-1
EOF

printf 'Création des données témoins\n'
printf 'MinVault restore test\n' > "$WITNESS_DIR/hello.txt"
printf 'checksum test\n' > "$WITNESS_DIR/checksum.txt"
printf 'unicode: sauvegarde vérifiée\n' > "$WITNESS_DIR/unicode.txt"
( cd "$WITNESS_DIR" && sha256sum ./* | sort ) > "$TEST_ROOT/checksums.before"
WITNESS_CREATED_AT="$(date +%s)"

printf 'Upload des témoins dans le bucket documents\n'
rclone --config "$TEST_RCLONE_CONFIG" copy "$WITNESS_DIR" "test:documents/$PREFIX" --checksum

printf 'Exécution d’une sauvegarde complète\n'
/usr/local/bin/backup.sh
BACKUP_FINISHED_AT="$(date +%s)"
RPO_SECONDS=$((BACKUP_FINISHED_AT - WITNESS_CREATED_AT))

printf 'Destruction contrôlée des données témoins sur la source\n'
rclone --config "$TEST_RCLONE_CONFIG" delete "test:documents/$PREFIX"
if rclone --config "$TEST_RCLONE_CONFIG" lsf "test:documents/$PREFIX" | grep -q .; then
  printf 'Erreur: les témoins n’ont pas été supprimés de la source.\n' >&2
  exit 1
fi

printf 'Restauration du dernier snapshot\n'
restic restore latest --target "$RESTORE_DIR"
RESTORED_WITNESS_DIR="$RESTORE_DIR/staging/documents/$PREFIX"
if [[ ! -d "$RESTORED_WITNESS_DIR" ]]; then
  printf 'Erreur: répertoire restauré absent: %s\n' "$RESTORED_WITNESS_DIR" >&2
  exit 1
fi
( cd "$RESTORED_WITNESS_DIR" && sha256sum ./* | sort ) > "$TEST_ROOT/checksums.after"

printf 'Comparaison des checksums\n'
if ! diff -u "$TEST_ROOT/checksums.before" "$TEST_ROOT/checksums.after"; then
  printf 'Erreur: checksums différents après restauration.\n' >&2
  exit 1
fi

FINISHED_AT="$(date +%s)"
RTO_SECONDS=$((FINISHED_AT - STARTED_AT))
RESULT="PASS"

printf 'RTO_SECONDS: %s\n' "$RTO_SECONDS"
printf 'RPO_SECONDS: %s\n' "$RPO_SECONDS"
printf 'RESULT: PASS\n'
