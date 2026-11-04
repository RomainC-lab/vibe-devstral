# Consignes générales (tous les projets)

## Langue
- Réponds en français, phrases courtes et simples. Le code, les noms et les commandes restent tels quels.

## Façon de travailler
- Avant une modification qui touche plus de 2 fichiers ou plus de ~50 lignes : donne d'abord un plan court (fichiers, étapes, risques) et attends mon accord.
- Lis le code concerné avant de le modifier ; ne devine pas un nom de fonction, de fichier ou d'option : vérifie avec `grep` ou `read_file`.
- Petits changements, un sujet à la fois. Pas de reformatage ni de renommage hors du sujet demandé.
- Garde le style du fichier (nommage, indentation, commentaires).
- S'il manque une information ou s'il y a deux choix raisonnables : pose la question au lieu de choisir au hasard.

## Mémoire
- Tu ne te souviens de rien d'une session à l'autre : seuls les fichiers `AGENTS.md` sont relus.
- Si le projet n'a pas d'`AGENTS.md`, propose de le créer avec la skill `creer-agents-md`.
- Quand je te corrige sur une chose qui reviendra (commande, règle, piège), ou que je dis « retiens », note-la avec la skill `retenir`.

## Avant de dire « c'est fait »
- Lance les tests du projet (ou la commande indiquée dans l'`AGENTS.md` du projet) et donne le résultat réel.
- Si tu n'as pas pu tester, dis-le clairement et explique comment je peux le faire.
- Termine par un résumé : fichiers modifiés, ce qui a été vérifié, ce qui reste à faire.

## Sécurité
- Ne lis pas, n'affiche pas et ne modifie pas les secrets : `.env`, clés, mots de passe, jetons, certificats.
- N'écris jamais un nom de serveur, un identifiant ou un mot de passe en dur dans le code ; utilise une variable d'environnement ou un fichier de réglages ignoré par Git.
- Pas de commande destructive (`rm -rf`, `git push --force`, `git reset --hard`, suppression de base de données) sans mon accord explicite.
- Ne fais ni `git commit` ni `git push` sans que je le demande.

## Environnement
- Windows 11, Git Bash, Python 3.12. Écris des chemins et des scripts qui marchent sous Windows (attention aux `\` et aux fins de ligne).
- Le code Python du travail vise **Python 3.11** (pas 3.12) : charge la skill `python-311`.

## Outils du travail (pas d'internet ici)
- Versions : NetBox 4.0.11, AAP 2.4 (automation controller 4.5.24), ansible-core 2.17, Python 3.11, Monkeyble 1.7.1 (tests de playbooks).
- Avant d'écrire du code ou une commande pour l'un d'eux, charge sa skill (`netbox`, `aap`, `ansible`, `python-311`, `monkeyble`) et suis cette version.
- Si la skill ne dit pas qu'une option ou une fonction existe dans cette version : dis-le et demande, n'invente pas.
