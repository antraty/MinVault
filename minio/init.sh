#!/usr/bin/env bash
set -euo pipefail

# Provisioning v0.4. Le script peut être relancé sans recréer ni casser les ressources.
export PATH="${HOME}/.local/bin:${PATH}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY_DIR="${ROOT_DIR}/minio/policies"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-https://s3.localhost}"
MINIO_ALIAS="${MINIO_ALIAS:-vault}"
MC_INSECURE="${MC_INSECURE:-1}"

required_vars=(
  MINIO_ROOT_USER MINIO_ROOT_PASSWORD
  APP_DOCS_SECRET APP_MEDIA_SECRET APP_LOGS_SECRET
  AUDITOR_SECRET BACKUP_AGENT_SECRET
)
for variable in "${required_vars[@]}"; do
  if [[ -z "${!variable:-}" || "${!variable}" == CHANGER_* ]]; then
    printf 'Erreur: la variable %s doit être définie dans .env\n' "$variable" >&2
    exit 1
  fi
done

command -v mc >/dev/null 2>&1 || {
  echo "Erreur: le client mc doit être installé et présent dans PATH." >&2
  exit 1
}

MC=(mc)
if [[ "$MC_INSECURE" == "1" ]]; then
  MC+=(--insecure)
fi

"${MC[@]}" alias set "$MINIO_ALIAS" "$MINIO_ENDPOINT" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null

ensure_policy() {
  local policy_name="$1"
  local policy_file="$2"
  if ! "${MC[@]}" admin policy info "$MINIO_ALIAS" "$policy_name" >/dev/null 2>&1; then
    "${MC[@]}" admin policy create "$MINIO_ALIAS" "$policy_name" "$POLICY_DIR/$policy_file"
    printf 'Politique créée : %s\n' "$policy_name"
  else
    printf 'Politique déjà présente : %s\n' "$policy_name"
  fi
}

ensure_user() {
  local access_key="$1"
  local secret_key="$2"
  if ! "${MC[@]}" admin user info "$MINIO_ALIAS" "$access_key" >/dev/null 2>&1; then
    "${MC[@]}" admin user add "$MINIO_ALIAS" "$access_key" "$secret_key"
    printf 'Utilisateur créé : %s\n' "$access_key"
  else
    printf 'Utilisateur déjà présent : %s\n' "$access_key"
  fi
}

attach_policy_user() {
  local policy_name="$1"
  local access_key="$2"
  "${MC[@]}" admin policy attach "$MINIO_ALIAS" "$policy_name" --user "$access_key"
}

ensure_policy rw-documents rw-documents.json
ensure_policy rw-media rw-media.json
ensure_policy write-logs write-logs.json
ensure_policy readonly-all readonly-all.json
ensure_policy backup-readonly backup-readonly.json
ensure_policy backup-immutable-write backup-immutable-write.json

for bucket in documents media logs backups; do
  if [[ "$bucket" == "backups" ]]; then
    "${MC[@]}" mb --ignore-existing --with-lock "$MINIO_ALIAS/$bucket" >/dev/null
  else
    "${MC[@]}" mb --ignore-existing "$MINIO_ALIAS/$bucket" >/dev/null
  fi
  "${MC[@]}" anonymous set none "$MINIO_ALIAS/$bucket" >/dev/null
  "${MC[@]}" version enable "$MINIO_ALIAS/$bucket" >/dev/null
  # Nettoyage des anciennes versions.
  "${MC[@]}" ilm rule add "$MINIO_ALIAS/$bucket" \
    --noncurrent-expire-days 30 \
    --expire-delete-marker >/dev/null 2>&1 || \
    printf 'Avertissement: règle ILM à vérifier pour %s (syntaxe mc variable selon version).\n' "$bucket" >&2
  printf 'Bucket sécurisé et versionné : %s\n' "$bucket"
done

# Object Lock cannot be enabled on an existing bucket. Keep the legacy bucket
# intact and provision a dedicated immutable bucket instead.
"${MC[@]}" mb --ignore-existing --with-lock "$MINIO_ALIAS/backups-immutable" >/dev/null
"${MC[@]}" anonymous set none "$MINIO_ALIAS/backups-immutable" >/dev/null
"${MC[@]}" version enable "$MINIO_ALIAS/backups-immutable" >/dev/null
"${MC[@]}" retention set --default compliance "${BACKUP_RETENTION:-30d}" "$MINIO_ALIAS/backups-immutable"

ensure_user app-docs "$APP_DOCS_SECRET"
attach_policy_user rw-documents app-docs
ensure_user app-media "$APP_MEDIA_SECRET"
attach_policy_user rw-media app-media
ensure_user app-logs "$APP_LOGS_SECRET"
attach_policy_user write-logs app-logs
ensure_user auditeur "$AUDITOR_SECRET"
attach_policy_user readonly-all auditeur
ensure_user backup-agent "$BACKUP_AGENT_SECRET"
attach_policy_user backup-readonly backup-agent
attach_policy_user backup-immutable-write backup-agent

# Le groupe d’audit permet d’ajouter d’autres comptes sans modifier la politique.
if ! "${MC[@]}" admin group info "$MINIO_ALIAS" auditors >/dev/null 2>&1; then
  "${MC[@]}" admin group add "$MINIO_ALIAS" auditors auditeur
else
  "${MC[@]}" admin group add "$MINIO_ALIAS" auditors auditeur >/dev/null 2>&1 || true
fi
"${MC[@]}" admin policy attach "$MINIO_ALIAS" readonly-all --group auditors

printf '\nProvisioning v0.4 terminé.\n'
"${MC[@]}" admin info "$MINIO_ALIAS"
