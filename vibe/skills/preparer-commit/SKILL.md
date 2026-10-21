---
name: preparer-commit
description: Vérifier les changements, créer une branche feature/ ou hotfix/ si besoin, et proposer un message de commit clair. À utiliser quand on demande de préparer, écrire ou faire un commit.
user-invocable: true
disable-model-invocation: true
allowed-tools:
  - bash
  - read_file
  - grep
---

# Préparer un commit

1. Regarde l'état : `git status` et `git diff` (plus `git diff --staged`).
2. Vérifie la branche : `git branch --show-current`.
   - Si elle commence par `feature/` ou `hotfix/`, continue.
   - Sinon (`main`, `master`, `develop`, autre nom, ou rien = HEAD détachée), il faut une nouvelle branche :
     - `hotfix/` pour une correction urgente de ce qui est en production, `feature/` pour le reste ;
       si tu ne sais pas lequel, demande-moi ;
     - nom court qui dit le sujet : minuscules, sans accent, mots séparés par des tirets
       (ex. `feature/export-inventaire-netbox`, `hotfix/vlan-manquant`) ;
     - vérifie qu'elle n'existe pas déjà (`git branch --list <nom>`) ;
     - propose le nom, et après mon accord lance `git switch -c <nom>` (les changements en cours suivent,
       rien n'est perdu), puis `git branch --show-current` pour vérifier.
   Ne commite jamais directement sur une branche qui ne commence pas par `feature/` ou `hotfix/`.
3. Vérifie avant tout :
   - aucun secret, mot de passe, jeton ou nom de serveur dans le diff ;
   - aucun fichier qui n'a rien à faire là (logs, `.env`, fichiers temporaires, gros binaires) ;
   - les tests du projet passent (lance-les si une commande est connue).
   S'il y a un problème, arrête-toi et explique-le.
4. Si les changements mélangent plusieurs sujets, propose de les séparer en plusieurs commits.
5. Propose le message, au style des derniers commits (`git log --oneline -10`) :
   - une première ligne courte (≤ 72 caractères) qui dit ce qui change ;
   - si utile, une ligne vide puis 1 à 3 lignes sur le pourquoi.
6. Montre la commande `git add …` puis `git commit -m "…"` et attends mon accord avant de la lancer. Ne fais jamais `git push`.
