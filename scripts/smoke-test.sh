#!/usr/bin/env bash
set -euo pipefail

https_port="${NGINX_HTTPS_PORT:-443}"
http_port="${NGINX_HTTP_PORT:-80}"
https_base="https://s3.localhost:${https_port}"

if [[ "$https_port" == "443" ]]; then
  https_base="https://s3.localhost"
fi

printf 'Vérification de la redirection HTTP sur le port %s\n' "$http_port"
curl --fail --silent --show-error --output /dev/null \
  --dump-header /tmp/minvault-http-headers \
  "http://s3.localhost:${http_port}/healthz"
grep -Eiq '^location: https://s3\.localhost|^location: https://s3\.localhost/' /tmp/minvault-http-headers
printf 'OK: HTTP redirige vers HTTPS\n'

printf 'Vérification de la santé du gateway sur %s\n' "$https_base"
curl --fail --silent --show-error --insecure "$https_base/healthz" | grep -qx 'ok'
printf 'OK: gateway HTTPS accessible\n'

for service in minio1 minio2 minio3 minio4 nginx; do
  docker compose ps --status running --services | grep -qx "$service"
  printf "OK: service %s en cours d'exécution\n" "$service"
done
