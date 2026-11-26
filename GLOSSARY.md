# MinVault

Vocabulaire du stockage objet et de la sauvegarde MinVault : buckets, credentials, chiffrement au repos, journal d'audit et rotation des secrets.

## Chiffrement

**Chiffrement forward-only** :
Chiffrement au repos appliqué aux seules écritures postérieures à son activation ; les objets antérieurs restent en clair.
_Avoid_: migration de chiffrement, ré-chiffrement, backfill

**Clé maître SSE** :
Clé unique partagée par toutes les instances MinIO du dépôt, utilisée pour le chiffrement au repos ; son remplacement rendrait les objets existants indéchiffrables.
_Avoid_: clé KMS, clé de chiffrement, clé de données

**Secret de dernier recours** :
Secret dont la perte rend des données définitivement irrécupérables et qui n'a aucun escrow dans ce dépôt.
_Avoid_: mot de passe de secours, clé de sauvegarde, secret de récupération

## Audit

**Événement d'audit** :
Enregistrement d'un appel à l'API S3 — identité, opération, cible, résultat, horodatage — émis par MinIO vers le récepteur d'audit.
_Avoid_: log, journal, trace

**Trace** :
Flux de diagnostic en direct destiné au débogage, non durable et sans garantie de livraison.
_Avoid_: audit, journal d'audit

**Récepteur d'audit** :
Service interne qui reçoit les événements d'audit et les ajoute au journal durable.
_Avoid_: collecteur, shipper, SIEM

**Livraison best-effort** :
Promesse selon laquelle un événement est écrit s'il atteint le récepteur, sans garantie en cas d'indisponibilité de celui-ci.
_Avoid_: livraison garantie, at-least-once

**Non infalsifiable** :
Qualité d'un journal qu'un opérateur disposant d'un accès root à l'hôte peut réécrire ; l'absence de cette qualité doit être assumée explicitement.
_Avoid_: immuable, inviolable, WORM

## Rotation

**Rotation** :
Remplacement du secret d'un credential de service, effectué avec une courte fenêtre de maintenance et une synchronisation des consommateurs.
_Avoid_: rotation de clé, changement de mot de passe, renouvellement

**Credential de service** :
Couple identifiant/secret d'un compte non-root dédié à une application ou à un agent.
_Avoid_: clé d'API, token, compte applicatif

**Consommateur** :
Service qui détient un credential de service et doit être redémarré après sa rotation.
_Avoid_: client, utilisateur, application

**Cérémonie manuelle** :
Rotation exécutée par l'opérateur selon le runbook, hors du script de rotation.
_Avoid_: procédure automatique, rotation planifiée
