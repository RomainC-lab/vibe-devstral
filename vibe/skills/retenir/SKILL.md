---
name: retenir
description: Noter durablement une consigne, une correction ou un piège du projet dans AGENTS.md pour s'en souvenir aux prochaines sessions. À utiliser quand l'utilisateur dit « retiens », « souviens-toi », « note que », ou corrige une erreur qui risque de revenir.
user-invocable: true
allowed-tools:
  - read_file
  - grep
  - edit
  - write_file
  - ask_user_question
---

# Retenir quelque chose

Vibe n'a pas de mémoire entre les sessions : seul l'`AGENTS.md` est relu à chaque fois. Ce qui doit être retenu va donc dedans.

1. Formule la chose à retenir en une ligne, à l'impératif et concrète (« Lance les tests avec `python -m pytest -q tests/` », pas « penser aux tests »).
2. Choisis le fichier :
   - propre à ce projet → `AGENTS.md` à la racine du projet (crée-le avec `/creer-agents-md` s'il n'existe pas) ;
   - valable pour tous les projets → `~/.vibe/AGENTS.md`.
   En cas de doute, demande avec `ask_user_question`.
3. Lis le fichier. Si une ligne dit déjà la même chose, ne la duplique pas. Si une ligne dit le contraire, remplace-la : jamais deux consignes qui se contredisent.
4. Ajoute la ligne dans la bonne partie (Commandes, Règles du projet, À ne pas toucher, Pièges connus). Pas de date, pas d'histoire : juste la consigne.
5. Jamais de mot de passe, de clé, de nom de serveur ni d'identifiant.
6. Garde le fichier court : s'il dépasse ~100 lignes, propose de fusionner ou d'enlever les lignes devenues inutiles.
7. Réponds en une ligne : ce qui a été noté, et dans quel fichier.
