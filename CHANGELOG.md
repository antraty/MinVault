# Changelog

Toutes les modifications notables de MinVault sont documentées dans ce fichier.

Le format suit les principes de [Keep a Changelog](https://keepachangelog.com/fr-FR/1.1.0/), et les versions suivent le [versionnage sémantique](https://semver.org/lang/fr/).

## [1.3.0] - 2026-11-19

### Ajouté
- **v1.1 (Forteresse)** : Durcissement Nginx, Object Lock sur `backups-immutable`, scans Gitleaks et Trivy.
- **v1.2 (Miroir)** : Alias rclone source et copie non destructive vers des buckets miroir sur `minio-backup`, avec contrôle d'intégrité.
- **v1.3 (Portail)** : Service applicatif FastAPI (`api/app.py`, `api/Dockerfile`) proposant une interface Web/Swagger pour la gestion des buckets, le téléchargement, l'envoi et la génération d'URL pré-signées.

## [Non publié]

### Ajouté
- Rétention Object Lock Compliance configurable et test de refus de suppression.
- Contrôle rclone automatisé de l'intégrité de la copie miroir après chaque sauvegarde de test.

## [1.0.0] - 2026-11-19

### Ajouté
- Version stable v1.0 avec documentation globale à jour, runbook complet et validation de l'ensemble de la suite de tests.

## [0.8.0] - 2026-11-19

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
- Image MinIO migrée vers Chainguard après le retrait des anciennes images communautaires sur Docker Hub et Quay.
- Images de service et images de base figées par digest pour des déploiements reproductibles.
- Résolution DNS dynamique Nginx pour suivre les IP Docker après la recréation de conteneurs MinIO.
- README et runbook alignés sur les ports locaux, les commandes Make et les prérequis `mc`.
- Buckets `documents`, `media`, `logs` et `backups` avec accès anonyme désactivé.
- Politiques IAM de moindre privilège et comptes dédiés pour les applications, l’audit et les sauvegardes.
- Versionnage et règles ILM configurés par un script de provisioning idempotent.
- Cible MinIO indépendante `minio-backup` avec volume séparé.
- Service `backup` basé sur rclone/restic, dépôt chiffré, rétention 7/4/6 et contrôle d’intégrité.
- Planification cron configurable et statut de dernière sauvegarde au format texte/Prometheus.
- Restauration manuelle d’un snapshot via `restore.sh`.
- Test automatisé de restauration avec données témoins, checksums, RTO/RPO et résultat `PASS/FAIL`.
- Stack de supervision Prometheus avec collecte des quatre nœuds MinIO.
- Règles d’alerte pour nœud indisponible, capacité faible et sauvegarde absente ou en échec.
- Dashboard Grafana provisionné automatiquement avec la datasource Prometheus.
- Exporter HTTP du statut de sauvegarde pour rendre `last_backup.prom` exploitable par Prometheus.
- Makefile avec commandes de cycle de vie, sauvegarde, restauration et validation.
- Suite de tests Bash reproductibles pour smoke test, politiques, accès anonyme, versionnage, sauvegarde, restauration et failover.
- Initialisation automatique des buckets et utilisateurs avant les tests fonctionnels.
- Workflows GitHub Actions v0.8 pour lint ShellCheck/yamllint/Hadolint, validation Compose, lint OpenAPI et intégration Docker.
- Contrat OpenAPI 3 pour les opérations S3 utilisées, les endpoints de santé MinIO et les métriques Prometheus.

### Limites connues

- La validation Docker complète est exécutée par le workflow GitHub Actions `.github/workflows/v06-restore.yml`; une exécution locale reste possible avec Docker Compose v2.
- La validation Docker complète dépend de GitHub Actions ou d'un environnement local équipé de Docker Compose v2.

## [0.1.0] - À venir

Première release après validation du critère v0.1.
