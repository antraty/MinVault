#!/usr/bin/env bash
set -euo pipefail

API_URL="${MINIO_API_URL:-http://localhost:9000}"

printf 'Vérification de MinIO sur %s\n' "$API_URL"
curl --fail --silent --show-error "$API_URL/minio/health/live" >/dev/null
printf 'OK: endpoint de santé accessible\n'

docker compose ps --status running --services | grep -qx minio
printf 'OK: service minio en cours d’exécution\n'
