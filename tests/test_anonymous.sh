#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

status="$(curl --insecure --silent --output /dev/null --write-out '%{http_code}' \
  "$MINIO_ENDPOINT/documents/minvault-anonymous-test.txt")"
[[ "$status" == "403" ]] || fail "accès anonyme attendu 403, obtenu $status"
ok 'accès anonyme refusé (403)'
