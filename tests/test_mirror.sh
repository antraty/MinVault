#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
mc_setup_aliases

object="mirror-failover-test-$$.txt"
printf 'MinVault mirror verification\n' >"/tmp/$object"
mc "${MC_FLAGS[@]}" cp "/tmp/$object" "docs-user/documents/$object" >/dev/null
docker compose run --rm backup rclone copy \
  "vault:documents/$object" "remote:${MIRROR_BUCKET_PREFIX:-minvault}-documents/"
mc "${MC_FLAGS[@]}" rm "docs-user/documents/$object" >/dev/null

if ! docker compose run --rm backup rclone cat \
  "remote:${MIRROR_BUCKET_PREFIX:-minvault}-documents/$object" |
  grep -Fxq 'MinVault mirror verification'; then
  rm -f "/tmp/$object"
  fail 'le témoin est absent du miroir après suppression sur la source'
fi

rm -f "/tmp/$object"
ok 'le miroir conserve une copie après suppression sur la source'
