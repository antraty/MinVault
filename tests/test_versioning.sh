#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
mc_setup_aliases

key="versioning-test-$$.txt"
printf 'version 1\n' > /tmp/version-1.txt
printf 'version 2\n' > /tmp/version-2.txt
mc "${MC_FLAGS[@]}" cp /tmp/version-1.txt "docs-user/documents/$key" >/dev/null
mc "${MC_FLAGS[@]}" cp /tmp/version-2.txt "docs-user/documents/$key" >/dev/null
versions="$(mc "${MC_FLAGS[@]}" ls --versions "docs-user/documents/$key")"
count="$(printf '%s\n' "$versions" | grep -c "$key" || true)"
[[ "$count" -ge 2 ]] || fail "au moins deux versions attendues, obtenu $count"
mc "${MC_FLAGS[@]}" rm --force --versions "docs-user/documents/$key" >/dev/null
ok 'versionnage conserve les anciennes versions'
