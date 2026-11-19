#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
mc_setup_aliases

if mc "${MC_FLAGS[@]}" ls media-user/documents >/dev/null 2>&1; then
  fail 'app-media peut lire le bucket documents'
fi
printf 'politique-test-%s\n' "$$" > /tmp/minvault-policy-test.txt
mc "${MC_FLAGS[@]}" cp /tmp/minvault-policy-test.txt docs-user/documents/policy-test.txt >/dev/null
mc "${MC_FLAGS[@]}" stat docs-user/documents/policy-test.txt >/dev/null
mc "${MC_FLAGS[@]}" rm docs-user/documents/policy-test.txt >/dev/null
ok 'les politiques séparent media et documents'
