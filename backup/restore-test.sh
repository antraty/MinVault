#!/usr/bin/env bash
set -euo pipefail

TEST_ROOT="${TEST_ROOT:-/tmp/minvault-restore-test}"
PREFIX=".minvault-restore-test"
WITNESS_DIR="$TEST_ROOT/witness"
RESTORE_DIR="$TEST_ROOT/restored"
STATUS_DIR="${STATUS_DIR:-/status}"
STARTED_AT="$(date +%s)"
RESULT="FAIL"

cleanup() {
  rm -rf "$TEST_ROOT"
  if [[ "$RESULT" != "PASS" ]]; then
    printf 'RESULT: FAIL\n'
  fi
}
trap cleanup EXIT

: "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY est requis}"
: "${RESTIC_PASSWORD:?RESTIC_PASSWORD est requis}"
: "${BACKUP_AGENT_SECRET:?BACKUP_AGENT_SECRET est requis}"

mkdir -p "$WITNESS_DIR" "$RESTORE_DIR" "$STATUS_DIR"

printf 'Création des données témoins\n'
printf 'MinVault restore test\n' > "$WITNESS_DIR/hello.txt"
printf 'checksum test\n' > "$WITNESS_DIR/checksum.txt"
printf 'unicode: sauvegarde vérifiée\n' > "$WITNESS_DIR/unicode.txt"
( cd "$WITNESS_DIR" && sha256sum ./* | sort ) > "$TEST_ROOT/checksums.before"
WITNESS_CREATED_AT="$(date +%s)"

printf 'Upload des témoins dans le bucket documents\n'
rclone copy "$WITNESS_DIR" "vault:documents/$PREFIX" --checksum

printf 'Exécution d’une sauvegarde complète\n'
/usr/local/bin/backup.sh
BACKUP_FINISHED_AT="$(date +%s)"
RPO_SECONDS=$((BACKUP_FINISHED_AT - WITNESS_CREATED_AT))

printf 'Destruction contrôlée des données témoins sur la source\n'
rclone delete "vault:documents/$PREFIX"
if rclone lsf "vault:documents/$PREFIX" | grep -q .; then
  echo 'Erreur: les témoins n’ont pas été supprimés de la source.' >&2
  exit 1
fi

printf 'Restauration du dernier snapshot\n'
restic restore latest --target "$RESTORE_DIR"
RESTORED_WITNESS_DIR="$RESTORE_DIR/staging/documents/$PREFIX"
if [[ ! -d "$RESTORED_WITNESS_DIR" ]]; then
  printf 'Erreur: répertoire restauré absent: %s\n' "$RESTORED_WITNESS_DIR" >&2
  exit 1
fi
( cd "$RESTORED_WITNESS_DIR" && sha256sum ./* | sed "s#  #  #" | sort ) > "$TEST_ROOT/checksums.after"

printf 'Comparaison des checksums\n'
if ! diff -u "$TEST_ROOT/checksums.before" "$TEST_ROOT/checksums.after"; then
  echo 'Erreur: checksums différents après restauration.' >&2
  exit 1
fi

FINISHED_AT="$(date +%s)"
RTO_SECONDS=$((FINISHED_AT - STARTED_AT))
cat > "$STATUS_DIR/restore-test.status" <<EOF
$(date -u '+%Y-%m-%dT%H:%M:%SZ') result=PASS rto_seconds=$RTO_SECONDS rpo_seconds=$RPO_SECONDS
EOF

RESULT="PASS"
printf 'RTO_SECONDS: %s\n' "$RTO_SECONDS"
printf 'RPO_SECONDS: %s\n' "$RPO_SECONDS"
printf 'RESULT: PASS\n'
