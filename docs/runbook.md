# Runbook MinVault — v0.2 Cluster

Ce runbook décrit le déploiement local du cluster MinVault : quatre nœuds MinIO distribués, avec erasure coding, volumes persistants et réseau Docker dédié.

## Prérequis

- Docker 24 ou supérieur
- Docker Compose v2 (`docker compose version`)
- `curl`
- Le client MinIO `mc`

> Cette configuration simule quatre nœuds sur une seule machine. Elle protège contre la panne d’un conteneur ou d’un volume, mais pas contre la perte de l’hôte entier.

## Démarrage

Depuis la racine du dépôt :

```bash
cp .env.example .env
# Modifier MINIO_ROOT_PASSWORD dans .env
set -a; . ./.env; set +a

docker compose up -d
docker compose ps
```

Les quatre conteneurs doivent passer à l’état `healthy` :

```bash
docker compose ps
for port in 9000 9001 9002 9003; do
  curl -fsS "http://localhost:${port}/minio/health/live" >/dev/null
  echo "API ${port}: OK"
done
```

## Accès aux consoles

Chaque nœud expose sa console sur un port distinct :

| Nœud | API S3 | Console |
|---|---:|---:|
| `minio1` | `9000` | `9100` |
| `minio2` | `9001` | `9101` |
| `minio3` | `9002` | `9102` |
| `minio4` | `9003` | `9103` |

La console principale est disponible à l’adresse <http://localhost:9100> avec les identifiants de `.env`.

## Configurer `mc` et vérifier le cluster

```bash
mc alias set vault http://localhost:9000 \
  "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"

mc admin info vault
```

La sortie doit indiquer quatre disques/nœuds et un état sain du cluster. Le format exact dépend de la version de `mc`.

## Opérations S3 de base

```bash
mc mb --ignore-existing vault/documents
printf 'MinVault v0.2\n' > /tmp/minvault-demo.txt
mc cp /tmp/minvault-demo.txt vault/documents/
mc ls vault/documents
mc cp vault/documents/minvault-demo.txt /tmp/minvault-restored.txt
cmp /tmp/minvault-demo.txt /tmp/minvault-restored.txt
```

Pour utiliser directement un autre nœud pendant un test :

```bash
mc alias set vault2 http://localhost:9001 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"
mc ls vault2/documents
```

## Test de panne et guérison

Ce test valide le critère v0.2 : les données restent accessibles lorsqu’un nœud est arrêté, puis le nœud rejoint le cluster après redémarrage.

1. Créer un objet témoin et enregistrer son checksum :

   ```bash
   printf 'objet de test v0.2\n' > /tmp/failover.txt
   mc cp /tmp/failover.txt vault/documents/failover.txt
   sha256sum /tmp/failover.txt
   ```

2. Arrêter `minio4` :

   ```bash
   docker compose stop minio4
   docker compose ps
   ```

3. Vérifier que le cluster répond encore via un autre nœud :

   ```bash
   mc alias set vault2 http://localhost:9001 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"
   mc cp vault2/documents/failover.txt /tmp/failover-restored.txt
   cmp /tmp/failover.txt /tmp/failover-restored.txt
   printf 'écriture pendant la panne\n' > /tmp/failover-new.txt
   mc cp /tmp/failover-new.txt vault2/documents/
   ```

4. Redémarrer le nœud et attendre sa guérison :

   ```bash
   docker compose start minio4
   docker compose ps
   mc admin heal -r vault
   mc admin info vault
   ```

5. Vérifier que l’objet est toujours lisible et que tous les nœuds sont sains :

   ```bash
   mc cp vault/documents/failover.txt /tmp/failover-after-heal.txt
   cmp /tmp/failover.txt /tmp/failover-after-heal.txt
   ```

## Arrêt et persistance

```bash
# Arrêter les conteneurs sans supprimer les volumes

docker compose down

# Redémarrer : les quatre volumes persistent

docker compose up -d

# Suppression irréversible de toutes les données locales
# À ne faire qu'en connaissance de cause
docker compose down -v
```

## Dépannage

```bash
docker compose logs --tail=100 minio1 minio2 minio3 minio4
docker compose ps
docker compose config
```

Si un port est déjà utilisé, modifier les ports correspondants dans `.env` puis relancer `docker compose up -d`.

## Critère de validation v0.2

La version est validée lorsque :

1. les quatre conteneurs sont `healthy` ;
2. `mc admin info vault` voit le cluster distribué ;
3. un objet est envoyé et récupéré ;
4. après l’arrêt d’un nœud, lecture et écriture restent possibles via un autre nœud ;
5. le nœud redémarré rejoint le cluster et la guérison s’exécute ;
6. les objets restent présents après un arrêt puis redémarrage complet.
