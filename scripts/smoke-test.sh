#!/usr/bin/env bash
set -euo pipefail

ports=(
  "${MINIO_API_PORT_1:-9000}"
  "${MINIO_API_PORT_2:-9001}"
  "${MINIO_API_PORT_3:-9002}"
  "${MINIO_API_PORT_4:-9003}"
)

for port in "${ports[@]}"; do
  api_url="${MINIO_API_URL:-http://localhost}:${port}"
  printf 'Vérification de MinIO sur %s\n' "$api_url"
  curl --fail --silent --show-error "$api_url/minio/health/live" >/dev/null
  printf 'OK: endpoint de santé accessible\n'
done

for service in minio1 minio2 minio3 minio4; do
  docker compose ps --status running --services | grep -qx "$service"
  printf 'OK: service %s en cours d’exécution\n' "$service"
done
