# Rotation en place des credentials de service, déclenchée par l'opérateur

Statut : accepté — 2026-11-26

## Contexte

v1.1 doit fournir une procédure de rotation des clés d'accès qui reste synchronisée avec les consommateurs. MinIO ne permet pas de modifier le secret d'un utilisateur : il faut le supprimer et le recréer, et les consommateurs ne lisent leur secret qu'au démarrage.

## Décision

Faire tourner, **en place et avec une courte fenêtre de maintenance**, les cinq credentials de service (`app-docs`, `app-media`, `app-logs`, `auditeur`, `backup-agent`) : arrêt des consommateurs, recréation de l'utilisateur avec le nouveau secret, réécriture atomique de `.env`, redémarrage, vérification. Les noms d'utilisateurs restent stables. Le script est **déclenché par l'opérateur**, jamais planifié ; la cadence recommandée (90 jours) vit dans le runbook. Un verrou empêche deux rotations concurrentes, et aucun ancien secret n'est conservé : un échec se rattrape en relançant la rotation.

Sont explicitement **hors rotation** : les comptes root (jusqu'à ce que `api` dispose d'un utilisateur dédié), `RESTIC_PASSWORD` (cérémonie manuelle) et la clé maître SSE (immuable par conception).

## Options écartées

- **Recouvrement sans coupure** (nouvel utilisateur daté, bascule, suppression de l'ancien) : aucune indisponibilité, mais les noms d'utilisateurs se mettent à tourner et le provisioning idempotent doit apprendre les générations — beaucoup de machinerie pour quelques secondes.
- **Rotation planifiée automatiquement** : contredit la contrainte selon laquelle aucun changement de clé ne peut avoir lieu sans synchroniser les consommateurs.
- **Sauvegarde de l'ancien `.env`** : l'ancien secret est déjà mort ; le conserver ne sert qu'à laisser un secret crédible sur le disque.

## Conséquences

- Chaque rotation provoque quelques secondes d'indisponibilité pour le credential concerné.
- Quatre des cinq credentials n'ont aucun consommateur dans la pile avant v1.3 : le test joue leur rôle et le runbook le dit, plutôt que de prétendre à une synchronisation inexistante.
- Les comptes root restent hors du dispositif tant que `api` s'authentifie avec eux.
