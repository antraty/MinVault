#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
mc_setup_aliases

# Extrait l'algorithme de chiffrement des métadonnées d'un objet.
sse_algorithm() {
  python3 -c '
import json, sys
document = json.loads(sys.stdin.readline())
metadata = {key.lower(): value for key, value in document.get("metadata", {}).items()}
print(metadata.get("x-amz-server-side-encryption", ""))
'
}

# Vérifie que le chiffrement par défaut du bucket s'applique à un objet écrit
# sans en-tête SSE : les métadonnées de l'objet doivent porter AES256.
assert_encrypted() {
  local target="$1"
  local algorithm
  algorithm="$(mc "${MC_FLAGS[@]}" stat --json "$target" | sse_algorithm)"
  if [[ "$algorithm" != "AES256" ]]; then
    fail "l’objet $target n’est pas chiffré en SSE-S3 (algorithme: '${algorithm:-absent}')"
  fi
}

# Même constat sur minio-backup, qui n'est joignable que depuis le réseau Compose.
assert_encrypted_on_backup() {
  local target="$1"
  local algorithm
  algorithm="$(mc_backup stat --json "$target" | sse_algorithm)"
  if [[ "$algorithm" != "AES256" ]]; then
    fail "l’objet $target n’est pas chiffré en SSE-S3 (algorithme: '${algorithm:-absent}')"
  fi
}

object="sse-test-$$.txt"
printf 'SSE test\n' >"/tmp/$object"

for bucket in documents media logs backups backups-immutable; do
  mc "${MC_FLAGS[@]}" cp "/tmp/$object" "vault/$bucket/$object" >/dev/null
  assert_encrypted "vault/$bucket/$object"
done

mc_backup_configure
for bucket in restic-repo \
  "${MIRROR_BUCKET_PREFIX:-minvault}-documents" \
  "${MIRROR_BUCKET_PREFIX:-minvault}-media" \
  "${MIRROR_BUCKET_PREFIX:-minvault}-logs"; do
  printf 'SSE test\n' | mc_backup pipe "backup/$bucket/$object" >/dev/null
  assert_encrypted_on_backup "backup/$bucket/$object"
done

rm -f "/tmp/$object"
ok 'les nouveaux objets sont chiffrés en SSE-S3 sur le cluster et sur minio-backup'
