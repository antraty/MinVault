# Changelog

Toutes les modifications notables de MinVault sont documentées dans ce fichier.

Le format suit les principes de [Keep a Changelog](https://keepachangelog.com/fr-FR/1.1.0/), et les versions suivent le [versionnage sémantique](https://semver.org/lang/fr/).

## [Non publié]

### Ajouté

- Socle MinIO mono-nœud via Docker Compose.
- Volume Docker nommé pour conserver les objets entre les redémarrages.
- Exemple de configuration sans secrets avec `.env.example`.
- Runbook de démarrage et d'opérations S3 de base.
- Smoke test initial de l'endpoint de santé.
- Cluster MinIO distribué à quatre nœuds avec erasure coding.
- Réseau Docker dédié et volumes persistants séparés par nœud.
- Healthchecks et ports de test distincts pour chaque nœud.
- Procédure de panne, redémarrage et guérison du cluster.
- Gateway Nginx devant le cluster avec upstream équilibré sur quatre nœuds.
- Certificats TLS auto-signés de développement pour `s3.localhost` et `console.localhost`.
- Redirection HTTP vers HTTPS, rate limiting, timeouts et taille maximale d’upload.
- Ports directs des nœuds MinIO retirés de l’exposition hôte.
- Image MinIO migrée vers `cgr.dev/chainguard/minio:latest` après le retrait des anciennes images communautaires sur Docker Hub et Quay.
- Buckets `documents`, `media`, `logs` et `backups` avec accès anonyme désactivé.
- Politiques IAM de moindre privilège et comptes dédiés pour les applications, l’audit et les sauvegardes.
- Versionnage et règles ILM configurés par un script de provisioning idempotent.
- Cible MinIO indépendante `minio-backup` avec volume séparé.
- Service `backup` basé sur rclone/restic, dépôt chiffré, rétention 7/4/6 et contrôle d’intégrité.
- Planification cron configurable et statut de dernière sauvegarde au format texte/Prometheus.
- Restauration manuelle d’un snapshot via `restore.sh`.
- Test automatisé de restauration avec données témoins, checksums, RTO/RPO et résultat `PASS/FAIL`.

### Limites connues

- La validation Docker complète est exécutée par le workflow GitHub Actions `.github/workflows/v06-restore.yml`; une exécution locale reste possible avec Docker Compose v2.
- La supervision Prometheus/Grafana, les tests élargis et la documentation OpenAPI restent planifiés pour v0.7/v0.8.

## [0.1.0] - À venir

Première release après validation du critère v0.1.
