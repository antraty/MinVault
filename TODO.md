# ✅ TODO — MinVault (Stockage objet & sauvegardes avec MinIO)

> Tâches **hors développement** : organisation, veille, documentation, branding, publication, communauté, finalisation.
> 🛣️ Le **développement et l'ajout des fonctionnalités** (cluster, Nginx/TLS, buckets, sauvegarde, restauration, supervision, tests, CI, OpenAPI, bonus) sont décrits dans [`ROADMAP.md`](ROADMAP.md) : ils ne sont pas répétés ici.

Cochez au fur et à mesure : `- [x]`

---

## 📊 Vue d'ensemble

| Bloc | Contenu | Durée indicative | Priorité |
|------|---------|------------------|----------|
| A | Cadrage, organisation, dépôt Git | 3 h | 🔴 Obligatoire |
| B | Veille technologique | 6 h | 🔴 Obligatoire |
| C | Documentation continue | 3 h (réparties) | 🔴 |
| D | Branding | 3 h | 🟠 |
| E | Publication (article + vidéo) | 6 h | 🟠 |
| F | Participation communautaire | 2 h | 🟠 |
| G | Finalisation, release, soutenance | 3 h | 🔴 |

> Les ≈ 50 h du livrable minimal se partagent entre ces blocs et les versions **v0.1 à v0.6** de la ROADMAP.

---

## 🧱 BLOC A — Cadrage et organisation (≈ 3 h)

- [ ] Lire l'énoncé et lister tous les livrables (minimal + communs)
- [ ] Choisir le **nom du projet** (provisoire : MinVault) et valider avec l'équipe
- [ ] Répartir les rôles (infra/cluster, sauvegarde, supervision, documentation, branding/publication)
- [ ] Choisir les outils de suivi : GitHub Projects / Trello, canal de discussion
- [ ] Créer le **dépôt Git public** (GitHub/GitLab)
- [ ] Ajouter `README.md`, `TODO.md`, `ROADMAP.md`, `LICENSE`, `.gitignore` (inclure `.env`, `certs/`, `*.key`)
- [ ] Définir la convention de commits (ex. Conventional Commits) et la stratégie de branches (`main`, `dev`, `feature/*`)
- [ ] Associer chaque version de la ROADMAP à un **tag Git** et à une entrée de `CHANGELOG.md`
- [ ] Préparer les postes : Docker, Docker Compose, `mc`, `aws-cli`, `git`, `openssl`
- [ ] Planifier le calendrier (jalons hebdomadaires, voir le planning en bas)

**✔ Critère de sortie :** dépôt prêt, équipe organisée, environnement fonctionnel.

---

## 🔎 BLOC B — Veille technologique (≈ 6 h)

Livrable : **fiche de 2 pages** (`docs/veille-technologique.pdf`).

- [ ] Définir le périmètre : stockage objet, S3, résilience des données
- [ ] Rassembler des sources fiables (docs officielles, articles techniques, benchmarks, spécifications)
- [ ] Comparer **au moins 3 outils** de stockage objet :
  - [ ] MinIO
  - [ ] Ceph (RADOS Gateway)
  - [ ] SeaweedFS
  - [ ] Garage
  - [ ] *(référence cloud)* AWS S3 / Backblaze B2
- [ ] Critères : compatibilité S3, facilité de déploiement, haute disponibilité, performances, licence, communauté, ressources requises, fonctionnalités (versionnage, Object Lock, réplication)
- [ ] Comparer aussi les outils de sauvegarde : **restic / borg / rclone / Kopia**
- [ ] Rédiger : état de l'art, tableau comparatif, avantages, limites, justification du choix
- [ ] Vérifier la **licence** de chaque outil (MinIO : AGPLv3) et l'activité récente du projet
- [ ] Citer les sources (liens + date de consultation)
- [ ] Relecture, mise en page sur 2 pages, export PDF
- [ ] Ajouter la fiche au dépôt

**✔ Critère de sortie :** fiche de 2 pages, ≥ 3 outils comparés, sources citées.

---

## 📝 BLOC C — Documentation continue (≈ 3 h, réparties)

À faire **au fur et à mesure** de l'avancement des versions de la ROADMAP.

- [ ] Tenir `docs/runbook.md` à jour (commandes, procédures d'exploitation, incidents)
- [ ] Mettre à jour le `README.md` à chaque version (commandes, captures, limites)
- [ ] Alimenter le `CHANGELOG.md` (format *Keep a Changelog*)
- [ ] Prendre des **captures d'écran** et enregistrer des **logs** à chaque étape clé (utiles pour l'article et la vidéo)
- [ ] Exporter le **schéma d'architecture** (`docs/architecture.png`)
- [ ] Noter les difficultés rencontrées et les solutions (matière pour l'article)
- [ ] Relire la documentation avec une personne extérieure à l'équipe

**✔ Critère de sortie :** un tiers comprend et déploie le projet sans aide.

---

## 🎨 BLOC D — Branding (≈ 3 h)

- [ ] Valider le **nom** définitif du projet
- [ ] Créer le **logo** (SVG + PNG) — Figma, Canva ou Inkscape
- [ ] Définir la **charte graphique minimale** : 2–3 couleurs, 1–2 polices, règles d'usage du logo
- [ ] Créer la **bannière du dépôt** (1280×640 px recommandé pour GitHub)
- [ ] Ajouter logo et bannière en tête du README
- [ ] Rédiger la **présentation de l'équipe** (noms, rôles, liens) dans le README
- [ ] Définir un slogan (ex. « Vos données, votre infrastructure »)
- [ ] Stocker les assets dans `docs/branding/`
- [ ] Ajouter les *topics* GitHub (`minio`, `s3`, `docker`, `backup`, `restic`, `rclone`, `prometheus`)

**✔ Critère de sortie :** identité visuelle cohérente sur le dépôt, l'article et la vidéo.

---

## 📣 BLOC E — Publication (≈ 6 h)

### Article / tutoriel
- [ ] Choisir la plateforme : Dev.to, Medium, LinkedIn ou blog de l'école
- [ ] Plan : problème → architecture → déploiement pas à pas → sécurité → sauvegarde → restauration → leçons apprises
- [ ] Inclure schémas, extraits de code et captures d'écran
- [ ] Relire, corriger, ajouter les liens vers le dépôt
- [ ] Publier et ajouter le lien dans le README

### Vidéo de démonstration (3 à 5 minutes)
- [ ] Écrire le **script** et le storyboard
- [ ] Trame : présentation (30 s) → déploiement `docker compose up` → buckets et politiques → versionnage → panne d'un nœud → sauvegarde → destruction puis **restauration réussie** → dashboard
- [ ] Enregistrer (OBS Studio), monter (DaVinci Resolve, CapCut ou Kdenlive)
- [ ] Ajouter sous-titres, logo, musique libre de droits
- [ ] Publier (YouTube, public ou non répertorié) et ajouter le lien au README

> ⚠️ L'article et la vidéo se préparent **après la v0.6** de la ROADMAP (la démonstration de restauration doit fonctionner).

**✔ Critère de sortie :** article publié, vidéo de 3 à 5 minutes en ligne.

---

## 🤝 BLOC F — Participation communautaire (≈ 2 h)

Au moins **une** contribution externe, avec preuve.

- [ ] Option 1 : répondre à une question sur **Stack Overflow** (tags `minio`, `restic`, `rclone`, `amazon-s3`)
- [ ] Option 2 : ouvrir une **issue** ou une **pull request** (documentation, correctif) sur MinIO, restic, rclone…
- [ ] Option 3 : présenter le projet à un **meetup**, un club ou un atelier de l'école
- [ ] Conserver la **preuve** (lien, capture d'écran) et l'ajouter au README

**✔ Critère de sortie :** contribution réalisée et lien disponible.

---

## 🏁 BLOC G — Finalisation, release et soutenance (≈ 3 h)

- [ ] Tester le déploiement **from scratch** sur une machine ou VM propre en suivant uniquement le README
- [ ] Vérifier l'absence de secrets dans l'historique Git (`gitleaks` ou recherche manuelle)
- [ ] Vérifier que tous les liens du README fonctionnent
- [ ] Nettoyer le dépôt (fichiers inutiles, `.gitignore`)
- [ ] Compléter les sections « Équipe » et « Livrables » du README
- [ ] Créer le tag `v1.0.0` et la **release GitHub** (notes de version)
- [ ] Rendre le dépôt **public**
- [ ] Préparer la soutenance : plan de présentation, démonstration live
- [ ] Préparer un **plan B** : la vidéo si la démonstration live échoue
- [ ] Répéter la présentation (durée, répartition de la parole, questions probables)

---

## 📋 Checklist finale des livrables

| Livrable | Fait |
|----------|------|
| Cluster MinIO fonctionnel *(ROADMAP v0.2)* | ☐ |
| Buckets sécurisés, versionnage *(ROADMAP v0.4)* | ☐ |
| Sauvegarde planifiée *(ROADMAP v0.5)* | ☐ |
| Test de restauration réussi *(ROADMAP v0.6)* | ✅ |
| Supervision Prometheus/Grafana et alertes *(ROADMAP v0.7)* | ✅ |
| Dépôt Git public + README + Docker Compose | ☐ |
| Tests de base + documentation d'API *(ROADMAP v0.8)* | ☐ |
| Fiche de veille (2 pages, ≥ 3 outils, sources) | ☐ |
| Article / tutoriel publié | ☐ |
| Vidéo de démonstration (3–5 min) | ☐ |
| Branding (nom, logo, charte, bannière, équipe) | ☐ |
| Contribution communautaire (≥ 1) | ☐ |

---

## 💡 À savoir sur ce projet

1. **Une sauvegarde non testée n'existe pas** : prévoyez des tests de restauration réguliers.
2. **Versionnage ≠ sauvegarde** : le premier protège des erreurs humaines, la seconde du sinistre.
3. **Ne perdez pas `RESTIC_PASSWORD`** : sans lui, les sauvegardes sont irrécupérables. Gardez-le dans un gestionnaire de mots de passe.
4. **Ne committez jamais de secrets** (`.env`, clés, certificats) : utilisez `.env.example`.
5. **Figez les versions** des images Docker dans la version finale.
6. **Vérifiez la syntaxe de `mc` et les noms de métriques** selon votre version de MinIO : ils évoluent.
7. **Un cluster sur une seule machine** n'est pas une vraie haute disponibilité : mentionnez-le honnêtement dans les limites.
8. **Licence MinIO (AGPLv3)** : à citer dans la veille et le README.
9. **Documentez au fur et à mesure** : cela alimente l'article, la vidéo et la veille.
10. **Gestion du temps (50 h)** : sécurisez d'abord la chaîne *cluster → sécurité → sauvegarde → restauration* avant le bonus.
11. **Soutenance** : préparez une démonstration en direct *et* une vidéo de secours.

---

## 🗓️ Planning conseillé (6 semaines)

Combine les blocs de ce TODO et les versions de la [`ROADMAP.md`](ROADMAP.md).

| Semaine | Ce TODO | ROADMAP |
|---------|---------|---------|
| 1 | Blocs A et B (cadrage, veille) | v0.1 |
| 2 | Bloc C (en continu) | v0.2, v0.3 |
| 3 | Bloc C (en continu) | v0.4 |
| 4 | Bloc C (en continu) | v0.5, v0.6 → **livrable minimal** |
| 5 | Blocs D et F (branding, communauté) | v0.7, v0.8 |
| 6 | Blocs E et G (article, vidéo, release, soutenance) | v1.0 (+ bonus si possible) |
