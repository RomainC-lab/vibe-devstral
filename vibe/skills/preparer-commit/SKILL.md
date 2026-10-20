---
name: preparer-commit
description: Vérifier les changements et proposer un message de commit clair. À utiliser quand on demande de préparer, écrire ou faire un commit.
user-invocable: true
disable-model-invocation: true
allowed-tools:
  - bash
  - read_file
  - grep
---

# Préparer un commit

1. Regarde l'état : `git status` et `git diff` (plus `git diff --staged`).
2. Vérifie avant tout :
   - aucun secret, mot de passe, jeton ou nom de serveur dans le diff ;
   - aucun fichier qui n'a rien à faire là (logs, `.env`, fichiers temporaires, gros binaires) ;
   - les tests du projet passent (lance-les si une commande est connue).
   S'il y a un problème, arrête-toi et explique-le.
3. Si les changements mélangent plusieurs sujets, propose de les séparer en plusieurs commits.
4. Propose le message, au style des derniers commits (`git log --oneline -10`) :
   - une première ligne courte (≤ 72 caractères) qui dit ce qui change ;
   - si utile, une ligne vide puis 1 à 3 lignes sur le pourquoi.
5. Montre la commande `git add …` puis `git commit -m "…"` et attends mon accord avant de la lancer. Ne fais jamais `git push`.
