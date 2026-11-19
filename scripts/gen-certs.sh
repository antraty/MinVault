#!/usr/bin/env bash
set -euo pipefail

CERT_DIR="${CERT_DIR:-nginx/certs}"
DAYS="${CERT_DAYS:-365}"
KEY_FILE="$CERT_DIR/minvault.key"
CERT_FILE="$CERT_DIR/minvault.crt"

mkdir -p "$CERT_DIR"

if [[ -s "$KEY_FILE" && -s "$CERT_FILE" && "${FORCE_CERT_RENEWAL:-0}" != "1" ]]; then
  printf 'Certificats déjà présents dans %s (utiliser FORCE_CERT_RENEWAL=1 pour régénérer).\n' "$CERT_DIR"
  exit 0
fi

umask 077
openssl req -x509 -nodes -newkey rsa:4096 \
  -keyout "$KEY_FILE" \
  -out "$CERT_FILE" \
  -days "$DAYS" \
  -subj "/CN=s3.localhost/O=MinVault (dev)" \
  -addext "subjectAltName=DNS:s3.localhost,DNS:console.localhost,DNS:localhost,IP:127.0.0.1"

chmod 600 "$KEY_FILE"
chmod 644 "$CERT_FILE"
printf 'Certificat TLS généré : %s\n' "$CERT_FILE"
