---
name: relire-diff
description: Relire les changements en cours (git diff) et signaler bugs, oublis et risques avant un commit. À utiliser quand on demande une relecture, une revue ou « vérifie mes changements ».
user-invocable: true
allowed-tools:
  - bash
  - read_file
  - grep
---

# Relecture des changements

1. Récupère les changements : `git status`, puis `git diff` (et `git diff --staged` s'il y a des fichiers indexés). Si l'utilisateur donne une branche, compare avec elle : `git diff <branche>...HEAD`.
2. Pour chaque fichier modifié, lis assez de contexte autour (`read_file`) pour comprendre le changement. Ne modifie aucun fichier.
3. Cherche, dans cet ordre :
   - bugs : logique fausse, cas limites (vide, None, erreur réseau), conditions inversées, mauvais index ;
   - oublis : appelants non mis à jour (`grep` sur le nom changé), tests manquants, docs ;
   - sécurité : secret, mot de passe ou nom de serveur en dur, entrée utilisateur non contrôlée ;
   - Windows : chemins, encodage, fins de ligne.
4. Réponds en français avec une liste, du plus grave au moins grave : `fichier:ligne`, le problème en une phrase, la correction proposée. Ne signale que ce qui est réel ; pas de remarques de goût.
5. Si tout est bon, dis-le en une ligne.
