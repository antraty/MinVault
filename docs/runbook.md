# Runbook MinVault — v0.1 Socle

Ce runbook décrit le déploiement local du socle MinVault : un serveur MinIO mono-nœud avec volume persistant.

## Prérequis

- Docker 24 ou supérieur
- Docker Compose v2 (`docker compose version`)
- `curl`
- Le client MinIO `mc` pour les commandes S3 ci-dessous

## Démarrage

Depuis la racine du dépôt :

```bash
cp .env.example .env
# Modifier MINIO_ROOT_PASSWORD dans .env

docker compose up -d
docker compose ps
```

Attendre que la colonne `Health` indique `healthy`, puis vérifier l'endpoint :

```bash
curl -fsS http://localhost:9000/minio/health/live
```

La console est disponible à l'adresse <http://localhost:9001> avec les identifiants de `.env`.

## Configurer `mc`

```bash
mc alias set vault http://localhost:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"
# Si les variables ne sont pas exportées :
# mc alias set vault http://localhost:9000 minvault-admin 'votre-mot-de-passe'

mc admin info vault
```

## Opérations S3 de base

```bash
# Créer un bucket
mc mb vault/documents

# Créer un fichier témoin et l'envoyer
printf 'MinVault v0.1\n' > /tmp/minvault-demo.txt
mc cp /tmp/minvault-demo.txt vault/documents/

# Lister le bucket
mc ls vault/documents

# Télécharger l'objet
mc cp vault/documents/minvault-demo.txt /tmp/minvault-restored.txt
cat /tmp/minvault-restored.txt

# Générer une URL de partage temporaire (durée par défaut du client)
mc share download vault/documents/minvault-demo.txt

# Supprimer l'objet puis le bucket de démonstration
mc rm vault/documents/minvault-demo.txt
mc rb vault/documents
```

## Arrêt et conservation des données

```bash
# Arrêter le conteneur sans supprimer le volume

docker compose down

# Redémarrer : les objets du volume persistent

docker compose up -d

# Suppression irréversible des données locales (à ne faire qu'en connaissance de cause)
docker compose down -v
```

## Dépannage

Consulter les logs :

```bash
docker compose logs --tail=100 minio
```

Afficher l'état et la configuration résolue :

```bash
docker compose ps
docker compose config
```

Si le port 9000 ou 9001 est déjà utilisé, modifier `MINIO_API_PORT` ou `MINIO_CONSOLE_PORT` dans `.env`, puis relancer `docker compose up -d`.

## Critère de validation v0.1

La version est validée lorsque :

1. le conteneur MinIO est `healthy` ;
2. `mc admin info vault` répond ;
3. un bucket peut être créé ;
4. un fichier peut être envoyé, listé et téléchargé ;
5. une URL pré-signée peut être générée ;
6. les objets restent présents après `docker compose down` puis `up -d`.
