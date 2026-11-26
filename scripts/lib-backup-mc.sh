#!/usr/bin/env bash
# Accès à l'instance minio-backup depuis l'hôte.
#
# minio-backup ne publie aucun port et son image ne contient pas mc. Pour la
# provisionner et la vérifier, on exécute le binaire mc de l'hôte dans un
# conteneur jetable attaché au réseau Compose : aucun port n'est publié et
# aucune image supplémentaire n'est nécessaire.
#
# Le binaire mc publié par MinIO est statique : il s'exécute tel quel dans Alpine.
# L'alias est créé à l'intérieur du conteneur à partir de variables transmises
# par nom : les secrets n'apparaissent jamais dans les arguments de commande.

BACKUP_MC_IMAGE="${BACKUP_MC_IMAGE:-alpine:3.21@sha256:bc21487101ae47172509130ee1092cc273a831968d64b617776d1f69c81e42ab}"
BACKUP_MC_NETWORK="${BACKUP_MC_NETWORK:-minvault_network}"

mc_backup_configure() {
  : "${BACKUP_MINIO_ROOT_USER:?BACKUP_MINIO_ROOT_USER est requis}"
  : "${BACKUP_MINIO_ROOT_PASSWORD:?BACKUP_MINIO_ROOT_PASSWORD est requis}"
  export BACKUP_MINIO_ROOT_USER BACKUP_MINIO_ROOT_PASSWORD
  export BACKUP_MC_ENDPOINT="${BACKUP_MC_ENDPOINT:-http://minio-backup:9000}"
}

mc_backup() {
  if ! command -v mc >/dev/null 2>&1; then
    printf 'Erreur: le client mc doit être installé sur l’hôte.\n' >&2
    return 1
  fi
  local binary
  binary="$(command -v mc)"
  if readlink -f "$binary" >/dev/null 2>&1; then
    binary="$(readlink -f "$binary")"
  fi
  docker run --rm --interactive \
    --network "$BACKUP_MC_NETWORK" \
    --env BACKUP_MC_ENDPOINT \
    --env BACKUP_MINIO_ROOT_USER \
    --env BACKUP_MINIO_ROOT_PASSWORD \
    --volume "${binary}:/usr/local/bin/mc:ro" \
    "$BACKUP_MC_IMAGE" sh -c '
      mc alias set backup "$BACKUP_MC_ENDPOINT" "$BACKUP_MINIO_ROOT_USER" "$BACKUP_MINIO_ROOT_PASSWORD" >/dev/null &&
      exec mc "$@"
    ' -- "$@"
}
