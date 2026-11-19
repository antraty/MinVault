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

### Limites connues

- La validation avec Docker reste à effectuer sur une machine disposant de Docker Compose v2.
- Les buckets, politiques, versionnage, sauvegardes et supervision seront ajoutés dans les prochaines étapes de la roadmap.

## [0.1.0] - À venir

Première release après validation du critère v0.1.
