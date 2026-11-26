# Chiffrement SSE-S3 avec une clé maître statique unique, en forward-only

Statut : accepté — 2026-11-26

## Contexte

v1.1 « Forteresse » doit livrer un chiffrement au repos, mais le dépôt reste volontairement auto-hébergé sur un seul hôte : pas de KMS externe, pas de KES, pas de Vault. Le cluster et `minio-backup` doivent être protégés, et la rotation des clés ne doit pas pouvoir casser les données existantes.

## Décision

Activer `SSE-S3` avec une **clé maître statique unique**, partagée par les quatre nœuds du cluster et par `minio-backup`, fournie par l'environnement. Le chiffrement est appliqué par défaut au niveau de chaque bucket, sur les deux instances. Il est **forward-only** : les objets antérieurs à l'activation restent en clair, et le runbook le dit explicitement. La clé maître n'est **pas rotative** : la changer rendrait tous les objets existants indéchiffrables.

## Options écartées

- **SSE-KMS via KES + KMS externe** : garantit une vraie séparation des clés, mais introduit une infrastructure externe hors périmètre de v1.1.
- **Une clé par instance** : meilleure séparation de rayon d'action, au prix de deux secrets à sauvegarder et d'une erreur de clé possible lors d'une reconstruction depuis `minio-backup`.
- **Chiffrement demandé par les clients** (en-tête seul) : produit un dépôt qui *paraît* chiffré alors que les objets écrits sans en-tête restent en clair.

## Conséquences

- Perdre la clé maître, c'est perdre les données : elle est un secret de dernier recours, au même rang que `RESTIC_PASSWORD`.
- Les objets antérieurs à v1.1 restent en clair jusqu'à une réécriture manuelle ; toute affirmation contraire serait fausse.
- Migrer vers SSE-KMS plus tard exigera de réécrire l'ensemble du jeu de données, pas seulement de changer une variable.
