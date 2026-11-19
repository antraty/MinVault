#!/usr/bin/env bash
set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"
: "${MINIO_ROOT_USER:?MINIO_ROOT_USER est requis}"
: "${MINIO_ROOT_PASSWORD:?MINIO_ROOT_PASSWORD est requis}"
: "${APP_DOCS_SECRET:?APP_DOCS_SECRET est requis}"
: "${APP_MEDIA_SECRET:?APP_MEDIA_SECRET est requis}"

MINIO_ENDPOINT="${MINIO_ENDPOINT:-https://s3.localhost}"
MC_INSECURE="${MC_INSECURE:-1}"
MC_FLAGS=()
[[ "$MC_INSECURE" == "1" ]] && MC_FLAGS+=(--insecure)

mc_setup_aliases() {
  mc "${MC_FLAGS[@]}" alias set vault "$MINIO_ENDPOINT" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null
  mc "${MC_FLAGS[@]}" alias set docs-user "$MINIO_ENDPOINT" app-docs "$APP_DOCS_SECRET" >/dev/null
  mc "${MC_FLAGS[@]}" alias set media-user "$MINIO_ENDPOINT" app-media "$APP_MEDIA_SECRET" >/dev/null
}

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }
