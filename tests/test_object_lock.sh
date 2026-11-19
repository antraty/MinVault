#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
mc_setup_aliases

object="object-lock-test-$$.txt"
printf 'WORM test\n' >"/tmp/$object"
mc "${MC_FLAGS[@]}" cp "/tmp/$object" "vault/backups-immutable/$object" >/dev/null
version_id="$(mc "${MC_FLAGS[@]}" ls --versions --json "vault/backups-immutable/$object" |
  python3 -c 'import json,sys; print(json.loads(sys.stdin.readline())["versionId"])')"
if mc "${MC_FLAGS[@]}" rm --version-id "$version_id" "vault/backups-immutable/$object" >/dev/null 2>&1; then
  fail 'la suppression d’un objet sous rétention Object Lock a réussi'
fi
mc "${MC_FLAGS[@]}" ls --versions --json "vault/backups-immutable/$object" |
  grep -Fq "\"versionId\":\"$version_id\"" ||
  fail 'la version verrouillée n’est plus présente après la tentative de suppression'
rm -f "/tmp/$object"
ok 'Object Lock refuse la suppression de la version verrouillée'
