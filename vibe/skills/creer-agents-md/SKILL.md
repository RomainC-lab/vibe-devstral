---
name: creer-agents-md
description: Créer ou mettre à jour le fichier AGENTS.md à la racine du projet en explorant le code. À utiliser quand on demande un AGENTS.md, ou quand le projet n'en a pas encore.
user-invocable: true
allowed-tools:
  - read_file
  - grep
  - bash
  - write_file
  - edit
  - ask_user_question
---

# Créer l'AGENTS.md du projet

But : un fichier court (moins de 80 lignes) qui permet à une nouvelle session de travailler juste, sans réexplorer tout le projet. N'y mets que des faits vérifiés.

1. S'il existe déjà un `AGENTS.md` à la racine, lis-le : tu le complètes, tu ne l'écrases pas. Garde tout ce qui vient de l'utilisateur.
2. Explore, sans rien modifier :
   - `git ls-files | head -200` et l'arborescence des dossiers principaux ;
   - le README, et les fichiers de projet (`pyproject.toml`, `requirements*.txt`, `setup.cfg`, `package.json`, `Makefile`, `tox.ini`, `.github/workflows/`, `Dockerfile`…) ;
   - `git log --oneline -15` pour le style des messages de commit ;
   - deux ou trois fichiers de code typiques pour le style (nommage, docstrings, langue des commentaires).
3. Trouve les vraies commandes (installer, lancer, tests, vérification du style). Essaie la commande de tests si elle est rapide et sans effet de bord ; note si elle marche.
4. S'il manque une info importante (commande de tests introuvable, dossier au rôle flou), pose au plus 3 questions avec `ask_user_question`.
5. Écris `AGENTS.md` avec ces parties, sans phrase inutile :
   - **En bref** : ce que fait le projet, en 1 ou 2 phrases.
   - **Organisation** : les dossiers importants et leur rôle, le point d'entrée.
   - **Commandes** : installer, lancer, tests, style ; exactes, à copier-coller.
   - **Règles du projet** : style, conventions, versions, dépendances.
   - **À ne pas toucher** : fichiers générés, `vendor/`, migrations appliquées, réglages locaux.
   - **Pièges connus** : laisse la partie vide si tu n'en connais pas ; `/retenir` la remplira.
6. Jamais de mot de passe, de clé, de nom de serveur ni d'identifiant dans ce fichier.
7. Montre le fichier et termine par : « Relis-le et corrige ce qui est faux : c'est ce que je lirai à chaque session. »
