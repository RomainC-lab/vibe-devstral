---
name: planifier
description: Préparer un plan avant de coder une fonctionnalité ou une correction non triviale, sans rien modifier. À utiliser quand on demande un plan, ou avant un changement qui touche plusieurs fichiers.
user-invocable: true
allowed-tools:
  - read_file
  - grep
  - bash
  - ask_user_question
---

# Plan avant de coder

Ne modifie aucun fichier pendant cette étape.

1. Reformule la demande en une ou deux phrases.
2. Explore le code concerné (`grep`, `read_file`, `git log -5 -- <fichier>`) jusqu'à savoir où se fait le changement.
3. S'il reste une vraie question (deux choix possibles, une info manquante), pose-la avec `ask_user_question`.
4. Donne le plan :
   - fichiers à modifier ou créer, et pourquoi ;
   - étapes numérotées, chacune petite et vérifiable ;
   - comment tester (commande exacte) ;
   - risques ou effets de bord.
5. Termine par : « Je commence ? » et attends la réponse.
