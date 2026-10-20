---
name: ecrire-tests
description: Écrire ou compléter des tests pour un fichier ou une fonction, puis les lancer. À utiliser quand on demande des tests, ou après une correction de bug.
user-invocable: true
allowed-tools:
  - read_file
  - grep
  - bash
  - write_file
  - edit
---

# Écrire des tests

1. Trouve comment le projet teste déjà : dossier `tests/`, `pytest.ini`, `pyproject.toml`, `package.json`… Utilise le même outil et le même style. Sans tests existants en Python : `pytest`, fichiers `tests/test_<module>.py`.
2. Lis le code à tester et liste les cas : cas normal, cas limites (vide, zéro, très grand, None), erreurs attendues. Pour un bug corrigé : un test qui échouait avant la correction.
3. Écris des tests courts, un comportement par test, avec des noms qui disent ce qui est vérifié. Pas d'accès réseau, pas de vrai serveur, pas de vraie base : remplace-les par des faux objets (mocks) ou des fichiers temporaires.
4. Lance les tests et montre le résultat réel. Si un test échoue, dis si c'est le test ou le code qui est faux, sans changer le code testé sans mon accord.
5. Résume : tests ajoutés, ce qu'ils couvrent, ce qui n'est pas couvert.
