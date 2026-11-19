# Runbook MinVault — v0.4 Coffre

Ce runbook décrit le cluster MinVault derrière un point d’entrée Nginx : HTTPS obligatoire, certificats locaux de développement, routage S3/console et ports directs MinIO non publiés.

## Prérequis

- Docker 24 ou supérieur
- Docker Compose v2 (`docker compose version`)
- `curl`, `openssl`
- Le client MinIO `mc`

> Cette configuration utilise des certificats auto-signés pour le développement. En production, utiliser un certificat délivré par une autorité de confiance et des noms DNS réels.

## Préparer les certificats et les hôtes locaux

Depuis la racine du dépôt :

```bash
cp .env.example .env
# Modifier MINIO_ROOT_PASSWORD dans .env
set -a; . ./.env; set +a

./scripts/gen-certs.sh
```

Les noms `s3.localhost` et `console.localhost` sont généralement résolus vers `127.0.0.1` par les navigateurs modernes. Si ce n’est pas le cas, ajouter ces lignes au fichier `/etc/hosts` :

```text
127.0.0.1 s3.localhost console.localhost
```

## Démarrage

```bash
docker compose up -d
docker compose ps
```

Le service `nginx` attend que les quatre nœuds MinIO soient sains. Vérifier le gateway :

```bash
curl --insecure --fail https://s3.localhost/healthz
curl --insecure --fail --head http://s3.localhost/healthz
```

La première commande doit renvoyer `ok`. La seconde doit afficher une redirection `301` vers HTTPS.

## Accès aux services

| Service | URL |
|---|---|
| API S3 | `https://s3.localhost` |
| Console MinIO | `https://console.localhost` |

Ouvrir la console dans un navigateur et accepter l’exception du certificat auto-signé de développement. Les ports `9000` à `9003` et `9001` des nœuds MinIO ne sont plus publiés sur l’hôte : les clients passent par Nginx.

## Configurer `mc` via le gateway

`mc` doit accepter le certificat de développement auto-signé :

```bash
mc alias set --insecure vault https://s3.localhost \
  "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"

mc admin info --insecure vault
```

## Initialiser les buckets et les comptes dédiés

Après avoir renseigné les secrets applicatifs dans `.env`, charger les variables puis lancer le provisioning :

```bash
set -a; . ./.env; set +a
./minio/init.sh
```

Le script est idempotent : il peut être relancé après une erreur ou un redémarrage. Il crée les buckets `documents`, `media`, `logs` et `backups`, désactive l’accès anonyme, active le versionnage, installe les règles ILM et configure les utilisateurs suivants :

| Utilisateur | Accès |
|---|---|
| `app-docs` | lecture/écriture dans `documents` uniquement |
| `app-media` | lecture/écriture dans `media` uniquement |
| `app-logs` | écriture dans `logs` uniquement |
| `auditeur` | lecture des données applicatives |
| `backup-agent` | lecture des buckets pour la sauvegarde |

Le compte root est réservé à l’administration du cluster. Les secrets ne doivent jamais être ajoutés à Git.

## Opérations S3 de base

```bash
mc mb --ignore-existing --insecure vault/documents
printf 'MinVault v0.3\n' > /tmp/minvault-demo.txt
mc cp --insecure /tmp/minvault-demo.txt vault/documents/
mc ls --insecure vault/documents
mc cp --insecure vault/documents/minvault-demo.txt /tmp/minvault-restored.txt
cmp /tmp/minvault-demo.txt /tmp/minvault-restored.txt

# URL pré-signée accessible via le gateway
mc share download --insecure vault/documents/minvault-demo.txt
```

## Validation des droits et du versionnage

Vérifier qu’un compte media ne peut pas lire le bucket documents :

```bash
mc alias set --insecure media-user https://s3.localhost app-media "$APP_MEDIA_SECRET"
if mc ls --insecure media-user/documents; then
  echo 'ERREUR: app-media peut lire documents' >&2
  exit 1
else
  echo 'OK: app-media est refusé sur documents'
fi
```

Vérifier qu’un objet supprimé reste récupérable grâce au versionnage :

```bash
printf 'version 1\n' > /tmp/versioned.txt
mc cp --insecure /tmp/versioned.txt vault/documents/versioned.txt
printf 'version 2\n' > /tmp/versioned.txt
mc cp --insecure /tmp/versioned.txt vault/documents/versioned.txt
mc rm --insecure vault/documents/versioned.txt

# Relever l’identifiant d’une ancienne version dans la sortie suivante.
mc ls --versions --insecure vault/documents/versioned.txt

# Restaurer une version choisie (remplacer VERSION_ID).
mc cp --insecure --version-id VERSION_ID \
  vault/documents/versioned.txt vault/documents/versioned.txt
```

Vérifier l’absence d’accès anonyme :

```bash
status=$(curl --insecure --silent --output /dev/null --write-out '%{http_code}' \
  https://s3.localhost/documents/versioned.txt)
test "$status" = 403
echo "OK: accès anonyme refusé ($status)"
```

## Test de panne et routage Nginx

Ce test valide qu’un nœud peut être arrêté sans interrompre l’accès via le point d’entrée unique.

1. Créer un objet témoin via HTTPS :

   ```bash
   printf 'objet de test v0.3\n' > /tmp/failover.txt
   mc cp --insecure /tmp/failover.txt vault/documents/failover.txt
   ```

2. Arrêter un nœud :

   ```bash
   docker compose stop minio1
   docker compose ps
   ```

3. Vérifier que le gateway continue de servir les données et accepte une écriture :

   ```bash
   mc cp --insecure vault/documents/failover.txt /tmp/failover-restored.txt
   cmp /tmp/failover.txt /tmp/failover-restored.txt
   printf 'écriture pendant la panne\n' > /tmp/failover-new.txt
   mc cp --insecure /tmp/failover-new.txt vault/documents/
   ```

4. Redémarrer le nœud et attendre sa guérison :

   ```bash
   docker compose start minio1
   docker compose ps
   mc admin heal -r --insecure vault
   mc admin info --insecure vault
   ```

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

## Critère de validation v0.4

La version est validée lorsque :

1. `https://s3.localhost` répond via Nginx ;
2. `https://console.localhost` affiche la console MinIO ;
3. HTTP redirige vers HTTPS ;
4. les quatre nœuds MinIO ne publient aucun port directement sur l’hôte ;
5. un fichier peut être envoyé et récupéré via `mc` ou `aws-cli` en HTTPS ;
6. après l’arrêt d’un nœud, le gateway continue de servir le cluster ;
7. `app-media` est refusé sur `documents` ;
8. un objet supprimé reste récupérable avec son ancienne version ;
9. une requête sans identifiants reçoit HTTP 403.
