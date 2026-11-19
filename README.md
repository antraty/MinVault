# 🗄️ MinVault — Stockage objet S3 auto-hébergé, sécurisé et sauvegardé

> **Projet L2 – Cloud** · Stockage objet compatible S3, versionnage, politiques d'accès, sauvegarde automatique et restauration testée.
> **Technologies :** MinIO · Docker / Docker Compose · restic · rclone · Nginx · Prometheus (+ Grafana)

---

## 📑 Sommaire

1. [Présentation](#1--présentation)
2. [Objectifs](#2--objectifs)
3. [Fonctionnalités](#3--fonctionnalités)
4. [Architecture](#4--architecture)
5. [Comment ça marche](#5--comment-ça-marche)
6. [Structure du dépôt](#6--structure-du-dépôt)
7. [Prérequis](#7--prérequis)
8. [Démarrage rapide](#8--démarrage-rapide)
9. [Configuration](#9--configuration)
10. [Buckets, utilisateurs et politiques d'accès](#10--buckets-utilisateurs-et-politiques-daccès)
11. [Versionnage et cycle de vie](#11--versionnage-et-cycle-de-vie)
12. [Sauvegarde et restauration](#12--sauvegarde-et-restauration)
13. [Supervision (Prometheus / Grafana)](#13--supervision-prometheus--grafana)
14. [Sécurité](#14--sécurité)
15. [Tests](#15--tests)
16. [Documentation de l'API](#16--documentation-de-lapi)
17. [Limites connues et pistes d'amélioration](#17--limites-connues-et-pistes-damélioration)
18. [Livrables du projet](#18--livrables-du-projet)
19. [Équipe, licence, remerciements](#19--équipe-licence-remerciements)

---

## 1. 📖 Présentation

**MinVault** est une plateforme de **stockage objet auto-hébergée**, compatible avec l'API **Amazon S3**, construite autour de **MinIO**.

Le stockage objet est la brique de base du cloud moderne : sauvegardes, fichiers statiques, médias, journaux, jeux de données, artefacts CI/CD… Les offres publiques (AWS S3, Google Cloud Storage, Azure Blob) sont pratiques mais coûteuses, soumises à une dépendance fournisseur (*vendor lock-in*) et parfois incompatibles avec des contraintes de souveraineté des données.

MinVault montre qu'on peut obtenir **le même modèle d'usage** (API S3, buckets, politiques IAM, versionnage) **sur sa propre infrastructure**, avec :

- une **haute disponibilité** (cluster MinIO distribué, *erasure coding*) ;
- un **accès sécurisé** (TLS, utilisateurs, politiques à moindre privilège) ;
- une **protection contre la perte et l'erreur humaine** (versionnage, verrouillage d'objets, sauvegardes planifiées) ;
- une **preuve de résilience** (test de restauration automatisé et documenté) ;
- une **observabilité** (métriques Prometheus, tableaux de bord, alertes).

**Public visé :** étudiants en cloud/DevOps, petites structures, associations, laboratoires, équipes souhaitant un S3 privé.

---

## 2. 🎯 Objectifs

### Objectif général
Mettre en place un stockage compatible S3 auto-hébergé avec politiques d'accès, versionnage et sauvegarde automatique.

### Objectifs spécifiques

| # | Objectif | Critère de réussite |
|---|----------|---------------------|
| O1 | Déployer un cluster MinIO distribué | 4 nœuds en bonne santé, `mc admin info` OK |
| O2 | Exposer le service derrière un reverse proxy TLS | Accès HTTPS via Nginx (API + console) |
| O3 | Sécuriser les buckets | Aucun accès anonyme, utilisateurs séparés, moindre privilège |
| O4 | Activer le versionnage | Une suppression/modification reste récupérable |
| O5 | Automatiser les sauvegardes | Tâche planifiée quotidienne, chiffrée et dédupliquée |
| O6 | Prouver la restauration | Script de test : restauration + vérification d'intégrité (checksum) |
| O7 | Superviser la plateforme | Métriques collectées, dashboard, alertes de base |
| O8 | Documenter et partager | README, veille, article, vidéo, contribution communautaire |

---

## 3. ⚙️ Fonctionnalités

### Stockage
- ✅ API **S3-compatible** (utilisable avec `aws-cli`, `mc`, `boto3`, `rclone`, SDKs…)
- ✅ **Cluster distribué** 4 nœuds avec **erasure coding** (tolérance à la perte de disques/nœuds)
- ✅ **Console web** d'administration MinIO
- ✅ **Chiffrement en transit** (TLS terminé par Nginx)
- ✅ *(Optionnel)* **Chiffrement au repos** (SSE-S3 via KMS/clé statique)

### Gouvernance et sécurité
- ✅ **Buckets séparés par usage** (`documents`, `media`, `backups`, `logs`)
- ✅ **Politiques d'accès** JSON (lecture seule, lecture/écriture, administrateur de bucket)
- ✅ **Utilisateurs et groupes** dédiés (pas d'usage du compte root au quotidien)
- ✅ **Versionnage** des objets
- ✅ **Règles de cycle de vie** (expiration des anciennes versions, nettoyage)
- ✅ *(Optionnel)* **Object Lock** (WORM) pour l'immuabilité des sauvegardes

### Sauvegarde et restauration
- ✅ **Sauvegarde planifiée** (cron/systemd timer) avec **restic** (chiffrée, dédupliquée, incrémentale)
- ✅ **rclone** pour la synchronisation vers un second site/stockage (autre MinIO, disque, cloud)
- ✅ **Politique de rétention** (`--keep-daily 7 --keep-weekly 4 --keep-monthly 6`)
- ✅ **Vérification d'intégrité** (`restic check`)
- ✅ **Test de restauration automatisé** avec comparaison de checksums

### Observabilité
- ✅ **Métriques Prometheus** (santé du cluster, capacité, requêtes, latence)
- ✅ **Dashboard Grafana** (optionnel mais recommandé)
- ✅ **Alertes** (nœud hors ligne, disque presque plein, échec de sauvegarde)

---

## 4. 🏗️ Architecture

```
                         ┌──────────────────────────────┐
   Clients S3  ─────────▶│  Nginx (reverse proxy, TLS)  │
 (mc, aws-cli, apps)     │   :443 → API (9000) / UI     │
                         └──────────────┬───────────────┘
                                        │ load balancing
              ┌─────────────┬───────────┴───┬─────────────┐
              ▼             ▼               ▼             ▼
         ┌────────┐    ┌────────┐      ┌────────┐    ┌────────┐
         │ minio1 │◀──▶│ minio2 │◀────▶│ minio3 │◀──▶│ minio4 │   Cluster distribué
         └───┬────┘    └───┬────┘      └───┬────┘    └───┬────┘   (erasure coding)
             │ vol          │ vol           │ vol         │ vol
             ▼              ▼               ▼             ▼
          data1          data2           data3         data4

   ┌──────────────────┐   métriques    ┌──────────────┐
   │   Prometheus     │◀───────────────│  /minio/v2/  │
   │  (+ Alertmanager │                │   metrics    │
   │   + Grafana)     │                └──────────────┘
   └──────────────────┘

   ┌──────────────────────────────────────────────────────────┐
   │ Conteneur "backup" (planifié)                            │
   │   rclone  : lit le cluster via S3 ─▶ staging              │
   │   restic  : snapshot chiffré/dédupliqué                   │
   │             ─▶ dépôt distant (2e MinIO "minio-backup"     │
   │                ou disque externe / autre site)            │
   └──────────────────────────────────────────────────────────┘
```

### Composants

| Composant | Rôle |
|-----------|------|
| **MinIO (×4)** | Stockage objet distribué, API S3, console |
| **Nginx** | Reverse proxy, terminaison TLS, répartition de charge, limitation de débit |
| **minio-backup** | Instance MinIO indépendante servant de cible de sauvegarde (site distinct simulé) |
| **restic** | Sauvegarde chiffrée, dédupliquée, avec snapshots et rétention |
| **rclone** | Accès/synchronisation S3, copie vers cibles externes |
| **Prometheus** | Collecte des métriques et évaluation des règles d'alerte |
| **Grafana** *(opt.)* | Visualisation |
| **mc (MinIO Client)** | Provisioning : buckets, utilisateurs, politiques, versionnage |

---

## 5. 🔍 Comment ça marche

### 5.1 Le cluster MinIO
MinIO est lancé en mode **distribué** : 4 conteneurs, chacun avec un volume. Les objets sont découpés en blocs de **données + parité** (*erasure coding*). Avec 4 disques, MinIO tolère la perte de plusieurs disques sans perdre de données (par défaut parité `EC:2` pour 4 disques : lecture possible avec 2 disques perdus, écriture avec 1 perdu selon la configuration du quorum).

### 5.2 Le point d'entrée Nginx
Les clients ne parlent jamais directement aux nœuds. **Nginx** reçoit les requêtes en HTTPS, les répartit entre les nœuds et protège l'accès (en-têtes, taille max d'upload, limitation de débit). La console web est exposée sur un sous-domaine ou un chemin séparé.

### 5.3 Le contrôle d'accès
Chaque application/personne possède un **utilisateur** MinIO auquel est attachée une **politique** (JSON, syntaxe IAM-like). Exemple : `app-media` peut lire/écrire dans `media` uniquement ; `auditeur` peut seulement lire `logs`. Aucun bucket n'est public.

### 5.4 Le versionnage
Quand le versionnage est activé, écraser ou supprimer un objet ne le détruit pas : MinIO conserve les versions précédentes (une suppression crée un *delete marker*). On peut **restaurer une ancienne version** ou annuler une suppression. Les règles de cycle de vie purgent les vieilles versions pour maîtriser l'espace.

### 5.5 La sauvegarde
Le versionnage protège des erreurs humaines **mais pas** d'une panne globale (incendie, corruption, ransomware, compromission du cluster). La sauvegarde ajoute donc une **copie indépendante** :

1. Une tâche planifiée démarre le conteneur `backup`.
2. **rclone** synchronise les buckets à protéger vers une zone de staging.
3. **restic** crée un **snapshot** chiffré et dédupliqué dans le dépôt cible (second MinIO ou autre).
4. La **rétention** supprime les vieux snapshots (`forget --prune`).
5. `restic check` vérifie l'intégrité ; un résultat est journalisé et exposé en métrique (succès/échec, durée, taille).

### 5.6 La restauration (preuve de résilience)
Le script `restore-test.sh` :
1. crée un jeu de données témoin et enregistre ses checksums (SHA-256) ;
2. lance une sauvegarde ;
3. **détruit** volontairement les données (ou un bucket) ;
4. restaure depuis le dernier snapshot ;
5. compare les checksums et affiche **PASS / FAIL**.

### 5.7 La supervision
MinIO expose ses métriques sur `/minio/v2/metrics/cluster`. Prometheus les collecte ; des règles d'alerte signalent : nœud injoignable, capacité > 80 %, sauvegarde absente depuis > 26 h.

---

## 6. 📂 Structure du dépôt

```
minvault/
├── README.md
├── TODO.md
├── LICENSE
├── .env.example                 # Variables (jamais de vrais secrets dans Git)
├── .gitignore
├── docker-compose.yml           # Cluster MinIO + Nginx + Prometheus + Grafana + backup
├── nginx/
│   ├── nginx.conf
│   └── certs/                   # Certificats (auto-signés en dev, ignorés par Git)
├── minio/
│   ├── policies/                # Politiques JSON (readonly, readwrite, ...)
│   └── init.sh                  # Création buckets, users, politiques, versionnage
├── backup/
│   ├── Dockerfile               # Image restic + rclone + cron
│   ├── backup.sh                # Sauvegarde + rétention + check
│   ├── restore.sh               # Restauration manuelle
│   ├── restore-test.sh          # Test de restauration automatisé
│   └── crontab
├── monitoring/
│   ├── prometheus.yml
│   ├── alerts.yml
│   └── grafana/                 # Dashboards provisionnés
├── scripts/
│   ├── deploy.sh
│   └── smoke-test.sh
├── tests/                       # Tests de base (bash/pytest + boto3)
├── api/
│   └── openapi.yaml             # Documentation OpenAPI (S3 + endpoints de service)
├── docs/
│   ├── veille-technologique.pdf # Fiche de veille (2 pages)
│   ├── architecture.png
│   ├── runbook.md               # Procédures d'exploitation / incident
│   └── branding/                # Logo, charte, bannière
└── .github/workflows/ci.yml     # Lint + tests automatiques
```

---

## 7. 🧰 Prérequis

- Linux / macOS / Windows (WSL2) avec **Docker ≥ 24** et **Docker Compose v2**
- ≥ 4 Go de RAM, ≥ 20 Go d'espace disque libre
- `git`, `curl`, `openssl`
- *(Optionnel)* le client **mc** et **aws-cli** sur la machine hôte pour tester

---

## 8. 🚀 Démarrage rapide

```bash
# 1. Cloner le dépôt
git clone https://github.com/<votre-compte>/minvault.git
cd minvault

# 2. Configurer l'environnement
cp .env.example .env
nano .env                       # Définir des mots de passe forts

# 3. Générer des certificats auto-signés (développement)
./scripts/gen-certs.sh

# 4. Démarrer toute la pile
docker compose up -d

# 5. Initialiser buckets, utilisateurs et politiques
docker compose run --rm mc /scripts/init.sh

# 6. Vérifier
./scripts/smoke-test.sh
```

**Accès (par défaut) :**

| Service | URL |
|---------|-----|
| API S3 | `https://s3.localhost` |
| Console MinIO | `https://console.localhost` |
| Prometheus | `http://localhost:9090` |
| Grafana | `http://localhost:3000` |

---

## 9. 🔧 Configuration

### Fichier `.env.example`

```ini
# --- MinIO (cluster principal) ---
MINIO_ROOT_USER=minvault-admin
MINIO_ROOT_PASSWORD=CHANGER_MOI_MOT_DE_PASSE_LONG
MINIO_PROMETHEUS_AUTH_TYPE=public

# --- MinIO (cible de sauvegarde) ---
BACKUP_MINIO_ROOT_USER=backup-admin
BACKUP_MINIO_ROOT_PASSWORD=CHANGER_MOI_AUSSI

# --- restic ---
RESTIC_REPOSITORY=s3:http://minio-backup:9000/restic-repo
RESTIC_PASSWORD=PHRASE_DE_PASSE_RESTIC_TRES_LONGUE
AWS_ACCESS_KEY_ID=backup-admin
AWS_SECRET_ACCESS_KEY=CHANGER_MOI_AUSSI

# --- Planification ---
BACKUP_CRON=0 2 * * *
```

> ⚠️ **Ne jamais committer le fichier `.env`.** Perdre `RESTIC_PASSWORD` = perdre l'accès aux sauvegardes. Conservez-le dans un gestionnaire de mots de passe.

### Extrait de `docker-compose.yml` (cluster)

```yaml
x-minio-common: &minio-common
  image: quay.io/minio/minio:latest   # À figer sur une version précise en production
  command: server http://minio{1...4}/data --console-address ":9001"
  environment:
    MINIO_ROOT_USER: ${MINIO_ROOT_USER}
    MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
    MINIO_PROMETHEUS_AUTH_TYPE: ${MINIO_PROMETHEUS_AUTH_TYPE}
  healthcheck:
    test: ["CMD", "mc", "ready", "local"]
    interval: 30s
    timeout: 20s
    retries: 3

services:
  minio1:
    <<: *minio-common
    hostname: minio1
    volumes: [data1:/data]
  minio2:
    <<: *minio-common
    hostname: minio2
    volumes: [data2:/data]
  minio3:
    <<: *minio-common
    hostname: minio3
    volumes: [data3:/data]
  minio4:
    <<: *minio-common
    hostname: minio4
    volumes: [data4:/data]

volumes: { data1: {}, data2: {}, data3: {}, data4: {} }
```

> 💡 Vérifiez la dernière syntaxe et les bonnes pratiques dans la documentation officielle MinIO : <https://min.io/docs/minio/container/index.html>. Les images et options évoluent ; **figez les versions** dans votre dépôt final.

---

## 10. 🔐 Buckets, utilisateurs et politiques d'accès

### Buckets prévus

| Bucket | Usage | Versionnage | Accès |
|--------|-------|-------------|-------|
| `documents` | Fichiers métier | ✅ | RW pour `app-docs`, R pour `auditeur` |
| `media` | Images/vidéos | ✅ | RW pour `app-media` |
| `logs` | Journaux applicatifs | ✅ (rétention courte) | W pour `app-*`, R pour `auditeur` |
| `backups` | Exports / copies | ✅ + *Object Lock* (opt.) | RW pour `backup-agent` uniquement |

### Exemple de politique (lecture/écriture sur un seul bucket)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::media"]
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": ["arn:aws:s3:::media/*"]
    }
  ]
}
```

### Commandes d'initialisation (`minio/init.sh`)

```bash
mc alias set vault https://s3.localhost "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"

# Buckets + versionnage
for b in documents media logs backups; do
  mc mb --ignore-existing vault/$b
  mc version enable vault/$b
done

# Politique + utilisateur
mc admin policy create vault rw-media /policies/rw-media.json
mc admin user add vault app-media "$APP_MEDIA_SECRET"
mc admin policy attach vault rw-media --user app-media

# Vérifier qu'aucun accès anonyme n'est autorisé
mc anonymous set none vault/media
```

> La syntaxe de `mc` a évolué entre versions (ex. `mc admin policy add` → `mc admin policy create`). Vérifiez avec `mc admin policy --help` sur votre version.

---

## 11. 🕘 Versionnage et cycle de vie

```bash
# Activer / vérifier
mc version enable vault/documents
mc version info vault/documents

# Voir les versions d'un objet
mc ls --versions vault/documents/rapport.pdf

# Restaurer une ancienne version (copie de la version choisie)
mc cp --version-id <ID> vault/documents/rapport.pdf vault/documents/rapport.pdf

# Règle de cycle de vie : supprimer les versions non courantes après 30 jours
mc ilm rule add vault/documents --noncurrent-expire-days 30
```

**Scénario de démonstration :** upload → modification → suppression accidentelle → récupération de la version précédente.

---

## 12. 💾 Sauvegarde et restauration

### Stratégie 3-2-1 (adaptée)
- **3** copies des données : cluster principal + sauvegarde + (option) copie externe
- **2** supports différents : cluster MinIO + dépôt restic sur autre instance/disque
- **1** copie hors site (simulée par `minio-backup` sur un autre hôte/réseau, idéalement réellement distant)

### Flux de sauvegarde (`backup/backup.sh` — principe)

```bash
#!/usr/bin/env bash
set -euo pipefail

STAGING=/staging
rclone sync vault:documents "$STAGING/documents" --fast-list --checksum
rclone sync vault:media     "$STAGING/media"     --fast-list --checksum

restic snapshots >/dev/null 2>&1 || restic init
restic backup "$STAGING" --tag minvault --host minvault

restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
restic check
```

### Planification
Dans le conteneur `backup`, `cron` exécute `backup.sh` selon `BACKUP_CRON` (par défaut : tous les jours à 02:00). Les sorties sont journalisées dans `/var/log/backup.log` et le statut est exposé à Prometheus (via fichier texte `node_exporter` textfile ou *Pushgateway*).

### Restauration

```bash
# Lister les snapshots
restic snapshots

# Restaurer le dernier snapshot dans /restore
restic restore latest --target /restore

# Remettre les fichiers dans le cluster
rclone sync /restore/staging/documents vault:documents
```

### Test de restauration automatisé

```bash
./backup/restore-test.sh
# ✔ Jeu de données créé (N fichiers, checksums enregistrés)
# ✔ Sauvegarde effectuée
# ✔ Données supprimées
# ✔ Restauration depuis snapshot
# ✔ Checksums identiques  →  RESULT: PASS
```

Ce test doit être exécuté **régulièrement** : *une sauvegarde jamais restaurée n'est pas une sauvegarde.*

---

## 13. 📊 Supervision (Prometheus / Grafana)

Extrait de `monitoring/prometheus.yml` :

```yaml
global:
  scrape_interval: 30s

rule_files:
  - alerts.yml

scrape_configs:
  - job_name: minio-cluster
    metrics_path: /minio/v2/metrics/cluster
    static_configs:
      - targets: ["minio1:9000"]
```

**Alertes de base** (`monitoring/alerts.yml`) :
- `MinioNodeDown` : un nœud ne répond plus depuis 2 min
- `MinioDiskUsageHigh` : utilisation > 80 %
- `BackupTooOld` : dernière sauvegarde réussie > 26 h

> Les noms exacts des métriques dépendent de la version de MinIO (ex. `minio_cluster_capacity_usable_free_bytes`). Vérifiez-les depuis l'endpoint avant d'écrire vos règles.

---

## 14. 🛡️ Sécurité

- 🔑 **Secrets** hors Git (`.env`, `.gitignore`) ; rotation documentée
- 🔒 **TLS** obligatoire (Nginx) ; certificats Let's Encrypt en production
- 👤 **Moindre privilège** : un utilisateur = une politique minimale ; le root n'est utilisé que pour l'administration
- 🚫 **Aucun accès anonyme** (`mc anonymous set none`)
- 🧱 **Réseau Docker isolé** : seuls Nginx (et éventuellement Grafana) sont exposés
- 🧾 **Journalisation** des accès (audit logs MinIO) *(optionnel)*
- 🧊 **Immuabilité** des sauvegardes via Object Lock *(optionnel)*
- 🧪 **Images figées** et analyse de vulnérabilités (ex. Trivy) *(optionnel)*
- 📏 **Limitation de débit / taille** configurée dans Nginx

---

## 15. ✅ Tests

| Test | Fichier | Vérifie |
|------|---------|---------|
| Smoke test | `scripts/smoke-test.sh` | Cluster up, API répond, console accessible |
| Droits d'accès | `tests/test_policies.*` | `app-media` ne peut pas lire `documents` |
| Accès anonyme | `tests/test_anonymous.*` | Refus 403 sans identifiants |
| Versionnage | `tests/test_versioning.*` | Suppression récupérable |
| Sauvegarde | `tests/test_backup.*` | Snapshot créé et valide |
| Restauration | `backup/restore-test.sh` | Checksums identiques après restauration |
| Tolérance aux pannes | `tests/test_failover.*` | Arrêt d'un nœud → service toujours disponible |

Exécution : `make test` (ou `./scripts/run-tests.sh`). La CI GitHub Actions exécute le lint (shellcheck, yamllint, hadolint) et les tests de base.

---

## 16. 📚 Documentation de l'API

MinVault utilise l'**API S3 standard** : la référence est la documentation Amazon S3 / MinIO. Le fichier [`api/openapi.yaml`](api/openapi.yaml) documente au format **OpenAPI 3** :

- les opérations S3 utilisées dans le projet (`PUT/GET/DELETE Object`, `ListObjectsV2`, `ListObjectVersions`, `PutBucketVersioning`…) ;
- les endpoints de service (santé : `/minio/health/live`, `/minio/health/cluster`, métriques : `/minio/v2/metrics/cluster`) ;
- les schémas d'authentification (AWS Signature V4) et des exemples de requêtes.

Exemples d'usage :

```bash
# aws-cli
aws --endpoint-url https://s3.localhost s3 cp fichier.txt s3://documents/

# Python (boto3)
import boto3
s3 = boto3.client("s3", endpoint_url="https://s3.localhost",
                  aws_access_key_id="app-media", aws_secret_access_key="***")
s3.put_object(Bucket="media", Key="hello.txt", Body=b"bonjour")
```

> Option bonus : un petit service **FastAPI** (`/upload`, `/files`, `/restore`) avec Swagger automatique, pour démontrer une application cliente du stockage.

---

## 17. ⚠️ Limites connues et pistes d'amélioration

**Limites**
- Un cluster sur **une seule machine** (Docker) protège des pannes de conteneurs/volumes, pas de la perte de l'hôte entier.
- La sauvegarde « hors site » est **simulée** si tout tourne sur la même machine.
- Les certificats auto-signés ne conviennent qu'au développement.
- Les fonctionnalités MinIO Community évoluent (certaines fonctions de la console ont été restreintes selon les versions) : consulter les notes de version.

**Pistes**
- Réplication de sites (*site replication* / *bucket replication*) entre deux clusters
- Chiffrement SSE-KMS, SSO/OIDC (Keycloak)
- Déploiement Kubernetes (opérateur MinIO) ou Terraform/Ansible
- Alertes via Alertmanager → e-mail / Telegram
- Comparaison de performances (`warp`) et plan de capacité

---

## 18. 📦 Livrables du projet

| Axe | Livrable | Emplacement / statut |
|-----|----------|----------------------|
| **Veille technologique** | Fiche de 2 pages : état de l'art, comparaison ≥ 3 outils (MinIO, Ceph/RGW, SeaweedFS, Garage…), avantages, limites, sources | `docs/veille-technologique.pdf` |
| **Technique** | Dépôt Git public, README, démo fonctionnelle, Docker Compose, tests de base, doc d'API (OpenAPI) | ce dépôt |
| **Publication** | Article/tutoriel (Medium, Dev.to, LinkedIn ou blog école) + **vidéo de démo 3–5 min** | liens à ajouter ci-dessous |
| **Branding** | Nom, logo, charte graphique minimale, bannière du dépôt, présentation d'équipe | `docs/branding/` |
| **Participation communautaire** | ≥ 1 contribution externe (réponse Stack Overflow, issue/PR open source, meetup, atelier) | liens à ajouter ci-dessous |

**Liens :**
- 📝 Article : _à compléter_
- 🎬 Vidéo de démo : _à compléter_
- 🤝 Contribution communautaire : _à compléter_

### Livrable minimal (50 h)
> Cluster MinIO · Buckets sécurisés · Sauvegarde planifiée · Test de restauration

---

## 19. 👥 Équipe, licence, remerciements

**Équipe :** _Noms, rôles et liens (GitHub/LinkedIn) à compléter._

**Licence :** MIT (à confirmer). Note : MinIO est distribué sous licence **AGPLv3** ; restic (BSD-2) et rclone (MIT).

**Références**
- MinIO — <https://min.io/docs/>
- restic — <https://restic.readthedocs.io/>
- rclone — <https://rclone.org/docs/>
- Nginx — <https://nginx.org/en/docs/>
- Prometheus — <https://prometheus.io/docs/>
- Documentation Amazon S3 (API de référence) — <https://docs.aws.amazon.com/s3/>

---

<p align="center"><i>MinVault — Vos données, votre infrastructure, votre contrôle.</i></p>
