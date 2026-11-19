# 🛣️ ROADMAP — MinVault

> Feuille de route **produit et développement** : quelles fonctionnalités sont ajoutées, dans quel ordre, et à quelle version.
> Elle complète le [`TODO.md`](TODO.md) (tâches détaillées, veille, publication, branding), mais ici on ne parle que de **développement et de fonctionnalités**.

**Légende :** 🔴 indispensable (livrable minimal) · 🟠 important · 🟢 bonus · ✅ fait · 🚧 en cours · ⏳ à faire

---

## 🗺️ Vue d'ensemble des versions

```
v0.1 ──▶ v0.2 ──▶ v0.3 ──▶ v0.4 ──▶ v0.5 ──▶ v0.6 ──▶ v1.0 ──▶ v1.1 ──▶ v1.2 ──▶ v2.0
Socle   Cluster  Accès    Données  Backup   Restore  Supervi- Release  Sécurité  Réplica-  Orchestration
MinIO   + HA     TLS      sécurisées planifiée testée  sion     stable   avancée   tion      & Cloud native
└────────────── LIVRABLE MINIMAL (50 h) ─────────────┘
```

| Version | Nom de code | Thème | Priorité | Statut |
|---------|-------------|-------|----------|----------|--------|
| v0.1 | **Socle** | MinIO mono-nœud + outils clients | 🔴 | ✅ |
| v0.2 | **Cluster** | Cluster distribué 4 nœuds (haute disponibilité) | 🔴 | ✅ |
| v0.3 | **Gateway** | Nginx, TLS, point d'entrée unique | 🔴 | ✅ |
| v0.4 | **Coffre** | Buckets, utilisateurs, politiques, versionnage | 🔴 | ✅ |
| v0.5 | **Filet** | Sauvegarde planifiée restic + rclone | 🔴 | 🚧 |
| v0.6 | **Preuve** | Restauration et test automatisé | 🔴 | ⏳ |
| v0.7 | **Vigie** | Supervision Prometheus / Grafana / alertes | 🟠 | ⏳ |
| v0.8 | **Qualité** | Tests, CI, documentation d'API | 🟠 | ⏳ |
| v1.0 | **Stable** | Première version complète et publique | 🔴 | ⏳ |
| v1.1 | **Forteresse** | Sécurité avancée (Object Lock, chiffrement, audit) | 🟢 | ⏳ |
| v1.2 | **Miroir** | Réplication et sauvegarde hors site | 🟢 | ⏳ |
| v1.3 | **Portail** | Service applicatif FastAPI + interface | 🟢 | ⏳ |
| v2.0 | **Cloud native** | Kubernetes / IaC / SSO | 🟢 | ⏳ |

---

## 🔴 v0.1 — Socle : MinIO mono-nœud

**Objectif :** disposer d'un stockage S3 fonctionnel et maîtriser les outils clients.

**Fonctionnalités**
- Conteneur MinIO unique avec volume persistant
- Console web d'administration accessible
- Client `mc` configuré (alias, commandes de base)
- Opérations S3 de base : créer un bucket, envoyer, lister, télécharger, supprimer un objet
- Compatibilité vérifiée avec `aws-cli` et `boto3`
- URL pré-signées (partage temporaire d'un objet)

**Livrables techniques**
- `docker-compose.yml` initial (1 service)
- `.env.example`
- `docs/runbook.md` (commandes de base)

**Critère de validation :** un fichier est envoyé et récupéré via console, `mc`, `aws-cli` et SDK Python.

---

## 🔴 v0.2 — Cluster : haute disponibilité

**Objectif :** passer d'un nœud unique à un cluster tolérant aux pannes.

**Fonctionnalités**
- Cluster MinIO distribué de 4 nœuds
- *Erasure coding* (données + parité)
- Healthchecks sur chaque nœud
- Réseau Docker dédié et volumes nommés par nœud
- Guérison automatique (*healing*) après redémarrage d'un nœud
- Versions d'images figées

**Livrables techniques**
- `docker-compose.yml` avec ancres YAML (`x-minio-common`)
- Procédure de test de panne dans le runbook

**Critère de validation :** avec 1 nœud arrêté, lecture et écriture restent possibles ; le nœud revient et se resynchronise.

---

## 🔴 v0.3 — Gateway : Nginx et TLS

**Objectif :** exposer le service de façon sécurisée via un point d'entrée unique.

**Fonctionnalités**
- Reverse proxy **Nginx** devant le cluster
- Répartition de charge entre les 4 nœuds
- HTTPS obligatoire (certificats auto-signés en dev) + redirection HTTP → HTTPS
- Sous-domaines distincts : API S3 et console
- Gestion des gros fichiers (taille max, timeouts, buffering)
- Limitation de débit (rate limiting)
- Fermeture des ports directs des nœuds MinIO

**Livrables techniques**
- `nginx/nginx.conf`
- `scripts/gen-certs.sh`

**Critère de validation :** `aws-cli` et la console fonctionnent en HTTPS ; un nœud en panne n'interrompt pas le service.

---

## 🔴 v0.4 — Coffre : buckets sécurisés et versionnage

**Objectif :** organiser et protéger les données.

**Fonctionnalités**
- Buckets par usage : `documents`, `media`, `logs`, `backups`
- **Utilisateurs et groupes** dédiés (le compte root n'est plus utilisé au quotidien)
- **Politiques d'accès** à moindre privilège (lecture seule, lecture/écriture par bucket)
- Suppression de tout accès anonyme
- **Versionnage** activé sur les buckets
- Restauration d'une version précédente / annulation d'une suppression
- **Règles de cycle de vie** : expiration des anciennes versions, nettoyage des uploads incomplets
- Script d'initialisation **idempotent**

**Livrables techniques**
- `minio/policies/*.json`
- `minio/init.sh`

**Critère de validation :** `app-media` ne peut pas lire `documents` ; un objet supprimé est récupérable ; accès anonyme refusé (403).

---

## 🔴 v0.5 — Filet : sauvegarde planifiée

**Objectif :** disposer d'une copie indépendante, chiffrée et automatique.

**Fonctionnalités**
- Cible de sauvegarde indépendante (`minio-backup` ou disque externe)
- Utilisateur `backup-agent` en lecture seule sur les sources
- Synchronisation avec **rclone**
- Snapshots **restic** : chiffrés, dédupliqués, incrémentaux
- Politique de rétention (7 jours / 4 semaines / 6 mois)
- Vérification d'intégrité (`restic check`)
- Planification **cron** (quotidienne par défaut)
- Journalisation et code de retour exploitable
- Exposition du statut de la dernière sauvegarde

**Livrables techniques**
- `backup/Dockerfile`, `backup/backup.sh`, `backup/crontab`

**Critère de validation :** une sauvegarde automatique s'exécute chaque nuit ; la seconde exécution est incrémentale (beaucoup plus rapide).

---

## 🔴 v0.6 — Preuve : restauration testée

**Objectif :** démontrer que les sauvegardes sont réellement exploitables.

**Fonctionnalités**
- Restauration manuelle d'un snapshot (fichier, bucket entier, point dans le temps)
- **Test de restauration automatisé** : données témoins → sauvegarde → destruction → restauration → comparaison de checksums (PASS/FAIL)
- Scénario de **sinistre total** (reconstruction du cluster depuis la sauvegarde)
- Mesure du **RTO** et du **RPO**

**Livrables techniques**
- `backup/restore.sh`, `backup/restore-test.sh`
- Procédure dans `docs/runbook.md`

**Critère de validation :** le test affiche `RESULT: PASS` avec des checksums identiques.

> 🎯 **Jalon : livrable minimal atteint** (cluster, buckets sécurisés, sauvegarde planifiée, test de restauration).

---

## 🟠 v0.7 — Vigie : supervision et alertes

**Objectif :** observer la santé du système et être prévenu des incidents.

**Fonctionnalités**
- Collecte des métriques MinIO par **Prometheus**
- Tableaux de bord **Grafana** : nœuds en ligne, capacité, requêtes/s, erreurs, trafic, latence
- Alertes de base :
  - nœud hors ligne
  - disque rempli à plus de 80 %
  - dernière sauvegarde trop ancienne (> 26 h)
- *(Optionnel)* Alertmanager vers e-mail ou Telegram
- Dashboards provisionnés automatiquement (pas de configuration manuelle)

**Livrables techniques**
- `monitoring/prometheus.yml`, `monitoring/alerts.yml`, `monitoring/grafana/`

**Critère de validation :** arrêter un nœud déclenche l'alerte correspondante.

---

## 🟠 v0.8 — Qualité : tests, CI et documentation d'API

**Objectif :** fiabiliser le projet et le rendre reproductible.

**Fonctionnalités**
- `Makefile` : `up`, `down`, `init`, `test`, `backup`, `restore-test`
- Suite de tests : smoke test, droits d'accès, accès anonyme, versionnage, sauvegarde, restauration, panne de nœud
- Intégration continue (shellcheck, yamllint, hadolint, validation Compose)
- Documentation **OpenAPI 3** : opérations S3 utilisées, endpoints de santé et de métriques, authentification SigV4
- *(Recommandé)* page Swagger UI publiée

**Livrables techniques**
- `tests/`, `.github/workflows/ci.yml`, `api/openapi.yaml`

**Critère de validation :** `make test` exécute toute la suite avec succès ; la CI est verte.

---

## 🔴 v1.0 — Stable : première version publique

**Objectif :** une version complète, reproductible et documentée.

**Contenu**
- Tout ce qui précède (v0.1 à v0.8) intégré et cohérent
- Déploiement *from scratch* en suivant uniquement le README
- Aucun secret dans l'historique Git
- Images Docker figées
- Release GitHub `v1.0.0` avec notes de version
- Démonstration complète (live + vidéo de secours)

**Critère de validation :** un tiers déploie le projet en moins de 15 minutes à partir du README.

---

## 🟢 v1.1 — Forteresse : sécurité avancée

**Fonctionnalités possibles**
- **Object Lock** (WORM) sur `backups` : protection contre la suppression et les ransomwares
- **Chiffrement au repos** (SSE-S3 / SSE-KMS)
- **Journaux d'audit** des accès MinIO
- Rotation automatisée des clés d'accès
- Analyse des images Docker (Trivy) dans la CI
- Détection de secrets (gitleaks) dans la CI
- Durcissement Nginx (en-têtes de sécurité, TLS moderne)

**Critère de validation :** une tentative de suppression d'une sauvegarde verrouillée est refusée.

---

## 🟢 v1.2 — Miroir : réplication et copie hors site

**Fonctionnalités possibles**
- **Réplication de buckets** vers un second cluster
- Sauvegarde externe via rclone vers un cloud (Backblaze B2, Wasabi…)
- Application réelle de la stratégie **3-2-1**
- Test de basculement (*failover*) entre sites
- Alerte en cas de retard de réplication

**Critère de validation :** un objet écrit sur le site A apparaît sur le site B ; restauration possible depuis le site B.

---

## 🟢 v1.3 — Portail : service applicatif

**Fonctionnalités possibles**
- Petite **API FastAPI** (Swagger automatique) : envoi, liste, téléchargement, URL pré-signée, restauration d'une version
- Authentification (JWT ou clés d'API)
- Interface web simple (liste des fichiers, historique des versions, bouton « restaurer »)
- Quotas par utilisateur / bucket
- Application de démonstration (galerie photo, dépôt de documents)

**Critère de validation :** un utilisateur envoie un fichier, le modifie, puis restaure l'ancienne version depuis l'interface.

---

## 🟢 v2.0 — Cloud native

**Fonctionnalités possibles**
- Déploiement **Kubernetes** (opérateur MinIO, Helm)
- **Infrastructure as Code** (Terraform / Ansible)
- **SSO / OIDC** (Keycloak)
- Sauvegardes via CronJob Kubernetes
- Benchmarks de performance (`warp`) et plan de capacité
- Alertmanager complet + astreinte simulée

---

## 🔗 Dépendances entre fonctionnalités

```
MinIO mono-nœud ─▶ Cluster ─▶ Nginx/TLS ─▶ Politiques & versionnage ─▶ Sauvegarde ─▶ Restauration
                                    │                                        │
                                    └────────────▶ Supervision ◀─────────────┘
                                                        │
                                              Tests / CI / OpenAPI ─▶ v1.0
                                                        │
                                  ┌─────────────────────┼─────────────────────┐
                                  ▼                     ▼                     ▼
                           Sécurité avancée      Réplication hors site   Portail FastAPI
                                  └─────────────────────┬─────────────────────┘
                                                        ▼
                                                   Cloud native
```

---

## ⚖️ Principes de priorisation

1. **Données d'abord** : stockage fiable avant les fonctionnalités annexes.
2. **Sécurité par défaut** : pas d'accès anonyme, moindre privilège, TLS dès v0.3.
3. **Pas de sauvegarde sans restauration** : v0.5 et v0.6 vont toujours ensemble.
4. **Chaque version est démontrable** : un critère de validation clair, testable.
5. **Le bonus ne commence qu'après la v1.0.**

---

## 📝 Journal des versions (à compléter au fil du projet)

| Version | Date | Changements principaux |
|---------|------|------------------------|
| v0.1 | 2026-11-19 | Socle Compose MinIO mono-nœud, volume persistant, configuration `.env.example`, runbook et smoke test initial. |
| v0.2 | 2026-11-19 | Cluster MinIO distribué à quatre nœuds, erasure coding, réseau dédié, volumes séparés et procédure de failover. |
| v0.3 | 2026-11-19 | Gateway Nginx, HTTPS local, routage API/console, rate limiting et fermeture des ports directs MinIO. |
| v0.4 | 2026-11-19 | Buckets sécurisés, utilisateurs dédiés, politiques IAM, versionnage, règles ILM et provisioning idempotent. |
| v0.5 | 2026-11-19 | Cible MinIO indépendante, synchronisation rclone, dépôt restic chiffré, rétention, check, cron et statut de run. |
| v0.6 | _à compléter_ | |
| v0.7 | _à compléter_ | |
| v0.8 | _à compléter_ | |
| v1.0 | _à compléter_ | |

> 💡 Chaque version doit correspondre à un **tag Git** (`v0.1.0`, `v0.2.0`…) et à une entrée dans un fichier `CHANGELOG.md` (format *Keep a Changelog*).
