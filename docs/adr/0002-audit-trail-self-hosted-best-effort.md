# Journal d'audit auto-hébergé, best-effort et non infalsifiable

Statut : accepté — 2026-11-26

## Contexte

v1.1 exige une journalisation d'audit durable des événements S3. MinIO n'écrit pas d'audit dans un fichier : il pousse chaque événement vers une cible webhook. Le déploiement reste mono-hôte, sans SIEM ni collecteur externe.

## Décision

Déployer un **récepteur d'audit** dédié, interne au réseau Compose, qui reçoit les événements des cinq services MinIO (cluster et `minio-backup`), les tague par instance source et les ajoute en NDJSON sur un volume persistant, avec rotation quotidienne, compression, rétention de 90 jours et plafond de 1 Gio. Aucun filtrage : les lectures sont auditées autant que les écritures. L'accès au journal est réservé à l'opérateur.

Les limites sont assumées et documentées : **livraison best-effort**, **mono-hôte**, **non infalsifiable**.

## Options écartées

- **Écrire l'audit dans le bucket `logs`** : les écritures du collecteur sont elles-mêmes des appels S3 (boucle de rétroaction), et le cluster compromis compromettrait son propre journal.
- **Capturer `mc admin trace`** : flux de diagnostic sans garantie de livraison ; l'appeler « durable » serait mensonger.
- **SIEM externe** : hors périmètre auto-hébergé de v1.1.

## Conséquences

- Un récepteur indisponible perd des événements ; le compteur de pertes doit rester visible pour que la limite soit mesurable, pas seulement déclarée.
- Un accès root à l'hôte permet de réécrire le journal : il ne vaut pas preuve devant un tiers.
- Couvrir `minio-backup` est indispensable : sans cela, la suppression du dépôt restic — l'action la plus destructrice du système — ne laisserait aucune trace.
