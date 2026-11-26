#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

export PATH="${HOME}/.local/bin:${PATH}"
set -a
source .env
set +a
export MINIO_ROOT_USER MINIO_ROOT_PASSWORD APP_DOCS_SECRET APP_MEDIA_SECRET
export MINIO_ENDPOINT="${MINIO_ENDPOINT:-https://s3.localhost}"
export MC_INSECURE="${MC_INSECURE:-1}"
export NGINX_HTTP_PORT="${NGINX_HTTP_PORT:-80}"
export NGINX_HTTPS_PORT="${NGINX_HTTPS_PORT:-443}"

./minio/init.sh
./scripts/smoke-test.sh
./tests/test_policies.sh
./tests/test_anonymous.sh
./tests/test_versioning.sh
bash ./tests/test_sse.sh
bash ./tests/test_object_lock.sh

docker compose run --rm backup /usr/local/bin/backup.sh
bash ./tests/test_mirror.sh
for bucket in documents media logs; do
  docker compose run --rm backup rclone check "vault:$bucket" "remote:${MIRROR_BUCKET_PREFIX:-minvault}-$bucket" --one-way
done
docker compose run --rm backup /usr/local/bin/restore-test.sh

docker compose stop minio1
trap 'docker compose start minio1 >/dev/null' EXIT
sleep 5
mc --insecure cp "${ROOT_DIR}/README.md" vault/documents/v08-failover-test.md >/dev/null
mc --insecure stat vault/documents/v08-failover-test.md >/dev/null
ok="OK: failover MinIO conserve lecture/ecriture pendant l'arret d'un nœud"
printf '%s\n' "$ok"
