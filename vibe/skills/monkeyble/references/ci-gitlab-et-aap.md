# Monkeyble 1.7.1 : CI GitLab, image d'exécution et AAP 2.4

## En bref
- Monkeyble est fait pour la CI : `monkeyble test` rend 0 si tout passe, 1 sinon. C'est tout ce que GitLab regarde.
- Pas de rapport JUnit : pas de `artifacts:reports:junit`. Garde la sortie console (et, si utile, un fichier log en artefact).
- Lance les tests avec les **mêmes versions** que le job AAP : ansible-core 2.17, Python 3.11, les mêmes versions de collections (`netbox.netbox`…) que le `collections/requirements.yml` du projet.
- Le callback ne doit être activé **que** dans la CI (par `ANSIBLE_CONFIG=monkeyble.cfg`), jamais dans l'`ansible.cfg` que lit AAP.

## Job GitLab CI (exemple)
À adapter : nom de l'image (souvent un registre interne au travail : demande lequel), étapes, règles. Cet exemple n'a pas été lancé dans un vrai GitLab ; les commandes du `script` ont été essayées à la main.
```yaml
# .gitlab-ci.yml (extrait)
stages:
  - test

monkeyble:
  stage: test
  image: python:3.11-slim          # ou l'image Python 3.11 du registre interne
  variables:
    ANSIBLE_CONFIG: "$CI_PROJECT_DIR/monkeyble.cfg"
    ANSIBLE_FORCE_COLOR: "true"
    PIP_CACHE_DIR: "$CI_PROJECT_DIR/.cache/pip"
  cache:
    key: monkeyble
    paths:
      - .cache/pip
  before_script:
    - python -m pip install "ansible-core>=2.17,<2.18" "monkeyble==1.7.1"
    - ansible-galaxy collection install -r tests/monkeyble/requirements.yml -p ./collections
  script:
    - bash -c 'set -o pipefail; monkeyble test | tee monkeyble.log'
  artifacts:
    when: always
    paths:
      - monkeyble.log
    expire_in: 1 week
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```
```yaml
# tests/monkeyble/requirements.yml
collections:
  - name: hpe.monkeyble
    version: "1.7.1"
  - name: netbox.netbox
    version: "3.21.0"     # mets la MÊME version que pour le job AAP
```
- `set -o pipefail` : sans lui, `| tee` cache le code de retour et le job serait toujours vert.
- **N'installe pas pynetbox** dans ce job : si un mock est oublié ou sauté (WARNING `Failure using method (v2_runner_on_start)`), le module NetBox échoue au lieu d'appeler un vrai serveur.
- Ne mets aucune vraie adresse NetBox ni vrai jeton dans les variables du job : les scénarios utilisent des valeurs factices.
- Sans accès à PyPI / Galaxy depuis les runners : image préparée à l'avance avec tout dedans, ou fichiers téléchargés ailleurs puis installés avec `pip install --no-index --find-links …` et `ansible-galaxy collection install <fichier>.tar.gz` (voir `installation.md`). Demande à l'utilisateur ce qui est permis.
- Pour un lint dans le même pipeline : un autre job `ansible-lint` (skill `ansible`, `references/ansible-lint.md`).
- Coffre (vault) : si le playbook lit un fichier chiffré, passe le mot de passe par une variable GitLab masquée et `ANSIBLE_VAULT_PASSWORD_FILE` ; mieux, donne des valeurs factices en `-e` pour que le test n'en ait pas besoin.

## Image d'exécution officielle (à utiliser avec prudence)
- Depuis 1.7.0 : `quay.io/hewlettpackardenterprise/monkeyble:latest` (et une étiquette par version, ex. `:1.7.1`). Elle contient la CLI, la collection `hpe.monkeyble` et un `/etc/ansible/ansible.cfg` avec `callbacks_enabled = monkeyble_callback`.
- Elle est construite sur Rocky Linux 10 avec **ansible-core 2.19** et ansible-runner 2.4 : ce n'est **pas** la version du travail (2.17). Le moteur de templates de 2.19 change des résultats (types, conditions). Pour des tests fidèles, préfère le job pip ci-dessus en 2.17, ou une image à toi.
- Usage documenté :
  ```bash
  docker run -it --rm -v ${PWD}:/runner/project/ -w /runner/project/ \
    quay.io/hewlettpackardenterprise/monkeyble:1.7.1 monkeyble test
  ```
- Image à toi avec ansible-builder (format `version: 3`) : pars de l'image d'exécution que le job AAP utilise vraiment (vérifie dedans `ansible --version`), et ajoute `monkeyble==1.7.1` en Python et `hpe.monkeyble` 1.7.1 en collection. Ne mets pas le callback dans le `/etc/ansible/ansible.cfg` d'une image qu'AAP utiliserait aussi.

## AAP 2.4 / automation controller 4.5.24 : ce qui marche ou non
Vérifié (code et essais Monkeyble 1.7.1) :
- Callback activé sans `monkeyble_scenario` en extra var → le playbook s'arrête tout de suite en erreur (`'monkeyble_scenario' need to be passed as extra_vars`, code 1). Donc : **jamais** `callbacks_enabled = hpe.monkeyble.monkeyble_callback` dans l'`ansible.cfg` à la racine du projet (AAP le lit pour les jobs de ce projet), ni `hpe.monkeyble` dans l'image d'exécution de production avec le callback activé.
- Monkeyble teste le playbook **en dehors** d'AAP : même playbook, mêmes rôles, mêmes versions, mais lancé par `ansible-playbook` dans la CI.
- Les réponses d'un survey AAP arrivent dans le playbook comme des **extra vars** : pour reproduire un job, mets les réponses type dans un fichier passé en `-e` (un fichier par cas), à côté des scénarios. Les variables de l'inventaire AAP et les credentials (variables injectées, ex. `netbox_url`/`netbox_token` d'un type de credential maison) n'existent pas en CI : donne des valeurs factices dans ce fichier.
- Un inventaire dynamique AAP (`nb_inventory`, inventaire « smart ») n'est pas disponible : donne un inventaire statique de test (`inventory:` dans `monkeyble.yml`), avec `ansible_connection: local`.

Non vérifié (ne l'affirme pas) :
- Lancer Monkeyble **dans** un job AAP (callback activé par variable d'environnement + `monkeyble_scenario` en extra var) : rien dans la doc Monkeyble ni essai. Le controller utilise son propre callback d'affichage via ansible-runner, et le callback Monkeyble arrête le processus (`sys.exit`) au premier test raté : le comportement du job (statut, sortie) est inconnu. Si l'utilisateur le veut, dis que c'est un essai à faire sur un controller de test, jamais en production.
- Le comportement exact avec les collections installées par AAP lors de la synchro du projet : non testé.

## Erreurs fréquentes en CI
- « Seems that Monkeyble callback has not started » : `ANSIBLE_CONFIG` n'est pas le bon chemin (mets un chemin absolu `$CI_PROJECT_DIR/…`), ou la collection n'est pas dans `collections_path`.
- Ansible ignore `ansible.cfg` dans un dossier accessible en écriture par tous (« Ansible is being run in a world writable directory … ignoring it as an ansible.cfg source ») : c'est pour ça qu'on passe le fichier par `ANSIBLE_CONFIG`.
- `ModuleNotFoundError: No module named 'ansible'` : ansible-core installé dans un autre Python que la CLI.
- Tous les tests passent mais rien n'est testé : vérifie dans la sortie les lignes `🙈`, `🙊`, `🙉` ; un nom de tâche mal recopié ne donne aucune erreur, juste aucun test.
