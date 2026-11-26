# Runbook MinVault — v1.0 Stable

Ce runbook décrit le cluster MinVault, sa configuration, sa supervision et ses procédures d'exploitation.

## Prérequis

- Docker 24 ou supérieur
- Docker Compose v2 (`docker compose version`)
- `curl`, `openssl`
- Le client MinIO `mc`

## Préparer les certificats et les hôtes locaux

Depuis la racine du dépôt :

```bash
cp .env.example .env
# Remplacer toutes les valeurs CHANGER_ dans .env par des secrets forts
```

Les noms `s3.localhost` et `console.localhost` sont généralement résolus vers `127.0.0.1` par les navigateurs modernes. Si ce n’est pas le cas, ajouter ces lignes au fichier `/etc/hosts` :

```text
127.0.0.1 s3.localhost console.localhost
```

## Démarrage

```bash
make up
docker compose ps
```

Le service `nginx` attend que les quatre nœuds MinIO soient sains. Le gateway utilise les ports configurés dans `.env` (8080/8443 par défaut) :

```bash
curl --insecure --fail https://s3.localhost:8443/healthz
curl --insecure --fail --head http://s3.localhost:8080/healthz
```

La première commande doit renvoyer `ok`. La seconde doit afficher une redirection `301` vers HTTPS.

## Accès aux services

| Service | URL |
|---|---|
| API S3 | `https://s3.localhost:8443` |
| Console MinIO | `https://console.localhost:8443` |
| Grafana (Supervision) | `https://grafana.localhost:8443` |

Ouvrir la console dans un navigateur et accepter l’exception du certificat auto-signé de développement. Les ports `9000` à `9003` et `9001` des nœuds MinIO ne sont plus publiés sur l’hôte : les clients passent par Nginx.

## Configurer `mc` via le gateway

`mc` doit accepter le certificat de développement auto-signé :

```bash
mc alias set --insecure vault https://s3.localhost:8443 \
  "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"

mc admin info --insecure vault
```

## Initialiser les buckets et les comptes dédiés

Après avoir renseigné les secrets applicatifs dans `.env`, charger les variables puis lancer le provisioning :

```bash
set -a; . ./.env; set +a
./minio/init.sh
```

Le script est idempotent : il peut être relancé après une erreur ou un redémarrage. Il crée les buckets `documents`, `media`, `logs` et `backups`, désactive l’accès anonyme, active le versionnage, installe les règles ILM et configure les utilisateurs.

Le bucket historique `backups` ne peut pas recevoir Object Lock après sa création. Le provisioning crée donc `backups-immutable` avec Object Lock en mode Compliance et une rétention par défaut (`BACKUP_RETENTION`, 30 jours par défaut). Le compte `backup-agent` peut lire et écrire dans ce bucket, mais ne possède pas le droit IAM de suppression. Les objets ne peuvent être supprimés qu'après la période de rétention.

Vérifier le verrouillage :

```bash
bash tests/test_object_lock.sh
mc --insecure retention info vault/backups-immutable
```

## Chiffrement au repos (v1.1)

Tous les nouveaux objets écrits dans le cluster et dans `minio-backup` sont chiffrés en SSE-S3 avec la clé maître définie par `MINIO_KMS_SECRET_KEY`. Le chiffrement est appliqué par défaut au niveau de chaque bucket : un client qui n’envoie pas d’en-tête de chiffrement obtient malgré tout un objet chiffré.

Générer la clé avant le premier démarrage :

```bash
printf 'minvault-sse:%s\n' "$(openssl rand -base64 32)" >> .env
```

La clé doit avoir la forme `nom:secret-base64` et décoder exactement 32 octets. `minio/init.sh` refuse de s’exécuter sinon, et MinIO refuse de démarrer si la valeur est mal formée.

**Secret de dernier recours.** Perdre cette clé rend les objets chiffrés définitivement indéchiffrables. Elle se sauvegarde hors du dépôt, au même rang que `RESTIC_PASSWORD`. Elle **n’est pas rotative** : la changer rendrait tous les objets existants illisibles (voir `docs/adr/0001`).

**Chiffrement forward-only.** Les objets écrits avant l’activation restent en clair. Pour les réécrire, en fenêtre de maintenance, recopier chaque objet sur lui-même en remplaçant ses métadonnées (CopyObject avec `REPLACE`). Une recette sûre passe par une clé temporaire :

```bash
# Exemple pour un objet précis ; généraliser avec une boucle sur la liste des objets.
mc --insecure cp vault/documents/objet.txt vault/documents/.rewrite/objet.txt
mc --insecure cp vault/documents/.rewrite/objet.txt vault/documents/objet.txt
mc --insecure rm vault/documents/.rewrite/objet.txt
```

Sur un bucket versionné, les anciennes versions en clair subsistent comme versions non courantes jusqu’à leur expiration ILM : la réécriture ne les efface pas. Sur `backups-immutable`, la rétention Compliance interdit la suppression : la réécriture n’y est possible que pour de nouveaux objets.

Vérifier le chiffrement effectif :

```bash
mc --insecure stat --json vault/documents/objet.txt | grep -i server-side-encryption
bash tests/test_sse.sh
```

## Opérations S3 de base

```bash
mc mb --ignore-existing --insecure vault/documents
printf 'MinVault v1.0\n' > /tmp/minvault-demo.txt
mc cp --insecure /tmp/minvault-demo.txt vault/documents/
mc ls --insecure vault/documents
mc cp --insecure vault/documents/minvault-demo.txt /tmp/minvault-restored.txt
cmp /tmp/minvault-demo.txt /tmp/minvault-restored.txt

# URL pré-signée accessible via le gateway
mc share download --insecure vault/documents/minvault-demo.txt
```

## Validation des droits, du versionnage et de l'anonymat

Les scripts de test automatisés valident ces mécanismes à chaque modification :

```bash
./tests/run-tests.sh
```

## Supervision et Alertes (v0.7)

MinVault intègre une supervision complète via Prometheus et Grafana.

- **URL Grafana :** `https://grafana.localhost:8443`
- **Dashboard :** "MinVault Overview" (provisionné automatiquement)
- **Alertes :** Configurées dans `monitoring/alerts.yml`, remontent dans le dashboard Grafana et via le service Alertmanager si configuré.

## Sauvegarde planifiée (v0.5)

La cible `minio-backup` est une instance MinIO séparée du cluster principal. Le service `backup` synchronise les buckets applicatifs avec `rclone`, crée un dépôt restic chiffré et applique la rétention `7 jours / 4 semaines / 6 mois`.

Pour lancer une sauvegarde immédiatement :

```bash
docker compose run --rm backup /usr/local/bin/backup.sh
```

Consulter le statut et les logs :

```bash
docker compose exec backup cat /status/last_backup.status
docker compose exec backup cat /status/last_backup.prom
docker compose exec backup tail -n 100 /var/log/minvault/backup.log
```

## Restauration automatisée (v0.6)

Le scénario de test de restauration complet est automatisé :

```bash
docker compose run --rm backup /usr/local/bin/restore-test.sh
```

Si le test affiche `RESULT: PASS`, les sauvegardes sont intègres et restaurables.


Le fichier `last_backup.prom` expose notamment `minvault_backup_success`, `minvault_backup_timestamp_seconds` et `minvault_backup_duration_seconds`. Un code de retour non nul indique un échec exploitable par cron ou une supervision ultérieure.

Vérifier manuellement le dépôt restic :

```bash
docker compose run --rm backup restic snapshots
docker compose run --rm backup restic check
```

La première exécution initialise le dépôt. Les exécutions suivantes sont incrémentales grâce à la déduplication restic.

### Miroir de réplication v1.2

À chaque sauvegarde, rclone lit les buckets sources avec l'alias `vault` (utilisateur `backup-agent`) et copie vers les buckets `minvault-documents`, `minvault-media` et `minvault-logs` de `minio-backup` (alias `remote`). La commande `copy` ne propage pas les suppressions de la source. La cible MinIO est distincte du cluster principal, mais si elle est hébergée sur la même machine, elle ne constitue pas un véritable site hors site ni une stratégie 3-2-1 complète.

Après une sauvegarde, contrôler la copie :

```bash
for bucket in documents media logs; do
  docker compose run --rm backup rclone check \
    "vault:$bucket" "remote:minvault-$bucket" --one-way
done
```

Le miroir est une copie de disponibilité, pas le dépôt restic chiffré. Pour obtenir une copie hors site réelle, définir une cible distante indépendante et protégée (réseau, identifiants et stockage dédiés) avant de déclarer la stratégie 3-2-1 satisfaite.

## Supervision v0.7

Prometheus collecte les métriques du cluster sur `/minio/v2/metrics/cluster` et le service `backup-exporter` relaie le fichier `/status/last_backup.prom` vers `/metrics`.

```bash
docker compose up -d backup-exporter prometheus grafana
curl -fsS http://localhost:9090/-/ready
curl -fsS http://localhost:3000/api/health
curl -fsS http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job, health, instance}'
curl -fsS 'http://localhost:9090/api/v1/rules?type=alert' | jq '.data.groups[].rules[] | {name, state}'
```

Le dashboard **MinVault Overview** est provisionné automatiquement dans Grafana. Les règles principales sont : `MinIOInstanceDown`, `MinIOClusterCapacityLow`, `MinIOBackupFailed` et `MinIOBackupStale`. Une sauvegarde absente depuis plus de 26 heures déclenche `MinIOBackupStale`.

Pour vérifier la fraîcheur de la métrique de sauvegarde :

```bash
docker compose run --rm backup /usr/local/bin/backup.sh
docker compose exec prometheus wget -qO- http://backup-exporter:9101/metrics
```

## Restauration et preuve v0.6

Restaurer manuellement le dernier snapshot dans `/restore` :

```bash
docker compose run --rm backup /usr/local/bin/restore.sh latest /restore
```

Restaurer un snapshot précis :

```bash
docker compose run --rm backup /usr/local/bin/restore.sh SNAPSHOT_ID /restore
```

Le test automatisé crée trois fichiers témoins dans `documents`, enregistre leurs checksums, lance une sauvegarde, supprime les témoins sur la source, restaure le dernier snapshot et compare les checksums. En cas d’échec, il écrit aussi `result=FAIL` dans le statut persistant et retourne un code non nul :

```bash
docker compose build backup
docker compose run --rm backup /usr/local/bin/restore-test.sh
```

Résultat attendu :

```text
RTO_SECONDS: N
RPO_SECONDS: N
RESULT: PASS
```

Le RTO mesure le temps entre le début du test et la validation des fichiers restaurés. Le RPO mesure ici l’âge des données témoins au moment où le snapshot de test est terminé. Le résultat persistant est disponible dans `/status/restore-test.status` sous la forme `result=PASS|FAIL rto_seconds=N rpo_seconds=N`.

La validation automatisée est rejouée par GitHub Actions via [`.github/workflows/v06-restore.yml`](../.github/workflows/v06-restore.yml), qui démarre la pile, provisionne les comptes, exécute le test et lance `restic check`.

## Arrêt et persistance

```bash
# Arrêter les conteneurs sans supprimer les volumes
docker compose down

# Redémarrer : les quatre volumes persistent
docker compose up -d

# Supprimer les volumes et les données locales (irréversible)
docker compose down -v
```

## Dépannage

```bash
docker compose logs --tail=100 nginx minio1 minio2 minio3 minio4
docker compose ps
docker compose config
nginx -t  # uniquement si nginx est installé sur l’hôte
```

Pour régénérer les certificats :

```bash
FORCE_CERT_RENEWAL=1 ./scripts/gen-certs.sh
docker compose restart nginx
```

## Critère de validation v0.6

La version est validée lorsque :

1. `https://s3.localhost:8443` répond via Nginx ;
2. `https://console.localhost:8443` affiche la console MinIO ;
3. HTTP redirige vers HTTPS ;
4. les quatre nœuds MinIO ne publient aucun port directement sur l’hôte ;
5. un fichier peut être envoyé et récupéré via `mc` ou `aws-cli` en HTTPS ;
6. après l’arrêt d’un nœud, le gateway continue de servir le cluster ;
7. `app-media` est refusé sur `documents` ;
8. un objet supprimé reste récupérable avec son ancienne version ;
9. une requête sans identifiants reçoit HTTP 403 ;
10. le dépôt restic est chiffré et contient un snapshot `minvault` ;
11. `restic check` termine avec succès ;
12. `last_backup.status` indique `success=1` après un run ;
13. une seconde exécution réutilise les données déjà présentes grâce à rclone/restic ;
14. `restore.sh` restaure un snapshot vers une cible locale ;
15. `restore-test.sh` affiche `RESULT: PASS` avec des checksums identiques ;
16. le test produit des mesures RTO et RPO.
