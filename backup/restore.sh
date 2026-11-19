#!/usr/bin/env bash
set -euo pipefail

SNAPSHOT="${1:-${RESTORE_SNAPSHOT:-latest}}"
TARGET="${2:-${RESTORE_TARGET:-/restore}}"

: "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY est requis}"
: "${RESTIC_PASSWORD:?RESTIC_PASSWORD est requis}"

mkdir -p "$TARGET"
printf 'Restauration du snapshot %s vers %s\n' "$SNAPSHOT" "$TARGET"
restic restore "$SNAPSHOT" --target "$TARGET"
printf 'Restauration terminée.\n'
printf 'Arborescence restaurée :\n'
find "$TARGET" -maxdepth 3 -type f -print | sort | head -100
