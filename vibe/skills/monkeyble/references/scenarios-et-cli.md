# Monkeyble 1.7.1 : scénarios, config et CLI

## En bref
- Un **scénario** = un cas d'usage du playbook (souvent tiré d'une user story) : des valeurs d'entrée + ce qu'on attend de certaines tâches.
- Les scénarios sont des **extra vars** : un fichier YAML passé en `-e @fichier`, avec la variable `monkeyble_scenarios`. On choisit le scénario avec `-e monkeyble_scenario=<nom>`.
- Le même fichier peut contenir les variables d'entrée du playbook (elles sont alors des extra vars, donc elles gagnent sur tout le reste).
- La CLI `monkeyble` lit un autre fichier, `monkeyble.yml` (la suite de tests), et lance un `ansible-playbook` par scénario.

## Fichier de scénarios
```yaml
# tests/monkeyble/scenarios.yml
# variables d'entrée du playbook (valeurs factices)
netbox_url: "https://netbox.exemple"
netbox_token: "FAUX-JETON"

monkeyble_scenarios:
  site_planifie:
    name: "Le rôle crée le site puis s'arrête car le site n'est pas actif"
    tasks_to_test:
      - task: "Créer le site du POP dans NetBox"
        should_be_changed: true
  site_actif:
    name: "Site actif : pas d'arrêt"
    tasks_to_test:
      - task: "Arrêter si le site n'est pas actif"
        should_be_skipped: true
```
- `name` est affiché (`Monkeyble scenario: …`) et repris dans les messages d'erreur.
- `tasks_to_test` : liste ; chaque entrée a au moins `task` (sinon « Monkeyble error: Task name need to be set »).
- Une tâche qui n'est dans aucune entrée s'exécute normalement, sans test ni mock.
- Scénario inconnu : `The Monkeyble scenario name '<nom>' not found in 'monkeyble_scenarios'`.

## Trouver la tâche
- Comparaison exacte avec le `name:` de la tâche, **après templating** (`name: "Créer {{ pop_site }}"` devient `Créer pop-exemple`). Sans le préfixe `role : ` affiché par Ansible.
- La première entrée qui correspond gagne. Deux tâches de même nom (deux rôles, deux plays) : ajoute un filtre.
- Filtres :
  ```yaml
  - task: "Créer le site du POP dans NetBox"
    role: "pop_netbox"     # testé seulement dans ce rôle (nom du rôle tel qu'Ansible le connaît)
    play: "Pop NetBox"     # testé seulement dans ce play (name: du play)
  ```
- Avec `role:`, une tâche hors rôle (dans le playbook) ne correspond jamais.

## Réutiliser de la config
Jinja dans les extra vars (les scénarios sont templatés au début du play avec les extra vars) :
```yaml
mock_vide:
  config:
    hpe.monkeyble.monkeyble_module:
      consider_changed: true
      result_dict: {}
monkeyble_scenarios:
  scenario_1:
    name: "…"
    tasks_to_test:
      - task: "Une tâche"
        mock: "{{ mock_vide }}"
```
- On peut répartir dans plusieurs fichiers : `-e @tests/monkeyble/mocks.yml -e @tests/monkeyble/scenarios.yml`.
- `monkeyble_shared_tasks` : liste d'entrées (comme `tasks_to_test`) ajoutée à **tous** les scénarios. Idéal pour un mock commun (jeton d'API, connexion NetBox…) :
  ```yaml
  monkeyble_shared_tasks:
    - task: "Lire le jeton NetBox dans le coffre"
      mock:
        config:
          hpe.monkeyble.monkeyble_module:
            result_dict:
              json: { token: "FAUX" }
  ```
  Elles passent après celles du scénario : une entrée du scénario de même nom gagne.

## extra_vars de Monkeyble
```yaml
monkeyble_scenarios:
  s1:
    name: "…"
    extra_vars:                 # pour toutes les tâches listées du scénario
      pop_status: "active"
    tasks_to_test:
      - task: "Créer le site du POP dans NetBox"
        extra_vars:             # gagne sur le niveau scénario
          pop_status: "offline"
```
- D'après le code 1.7.1 : ces valeurs servent à re-templater **les arguments du module** des tâches listées dans `tasks_to_test`. Elles ne changent pas un `when:`, un `set_fact` déjà fait, ni les tâches non listées.
- Pour changer une variable partout (y compris les `when:`), mets-la dans un fichier passé en `-e` (une entrée `extra_vars` de `monkeyble.yml`). C'est ce qu'on fait pour tester plusieurs valeurs d'entrée : un petit fichier par cas.

## La CLI

### monkeyble.yml (la suite de tests)
Cherché dans cet ordre (le premier trouvé gagne) : option `-c CHEMIN`, variable d'environnement `MONKEYBLE_CONFIG`, puis `monkeyble.yml` du dossier courant. Le nom `monkeyble.yaml` n'est lu que via `-c` ou `MONKEYBLE_CONFIG`.
```yaml
# monkeyble.yml (lu en YAML simple : pas de Jinja ici)
monkeyble_global_extra_vars:      # ajoutés à tous les tests, en premier
  - "tests/monkeyble/mocks.yml"
monkeyble_test_suite:
  - playbook: "playbooks/pop.yml"   # obligatoire
    inventory: "tests/monkeyble/inventaire.yml"   # facultatif (sinon localhost implicite)
    extra_vars:                    # chemins de fichiers, dans l'ordre (le dernier gagne)
      - "roles/pop_netbox/defaults/main.yml"
      - "tests/monkeyble/scenarios.yml"
    scenarios:                     # obligatoire
      - "site_planifie"
  - playbook: "playbooks/pop.yml"
    extra_vars:
      - "tests/monkeyble/scenarios.yml"
      - "tests/monkeyble/cas-actif.yml"
    scenarios:
      - "site_actif"
```
- Chemins relatifs au dossier d'où on lance `monkeyble`.
- Pas de motif `*.yml` : un fichier par ligne.

### Commandes
```bash
ANSIBLE_CONFIG=monkeyble.cfg monkeyble test                       # toute la suite
ANSIBLE_CONFIG=monkeyble.cfg monkeyble test --limit s1 s2         # seulement ces scénarios
monkeyble list                                                    # tableau playbook / scénarios
monkeyble test -c tests/monkeyble/monkeyble.yml
monkeyble -v                                                      # version
```
- Pour chaque scénario la CLI lance exactement : `ansible-playbook <playbook> [-i <inventory>] -e @<fichier>… -e monkeyble_scenario=<nom>`. Aucune autre option possible : passe le reste par l'environnement, qui est transmis (`ANSIBLE_CONFIG`, `ANSIBLE_VAULT_PASSWORD_FILE`, `ANSIBLE_VERBOSITY=1`…).
- À la fin : un tableau `Playbook | Scenario | Test passed` (✅/❌), la durée, `Tests passed: X of Y tests`, et le code de retour 1 si au moins un scénario a échoué, 0 sinon.
- Erreurs de la CLI : « No 'monkeyble_test_suite' variable defined », « Missing 'playbook' key in a test », « No scenarios for playbook … », « Seems that Monkeyble callback has not started. Check your Ansible config. ».

## Lire la sortie d'un playbook
- `🐵 Starting Monkeyble callback 1.7.1` puis `monkeyble_scenario: …` : callback chargé.
- `🙈 Monkeyble test input passed ✔` + JSON `monkeyble_passed_test` / `monkeyble_failed_test`.
- `🙉 Monkeyble mock module - Before: 'netbox.netbox.netbox_site' Now: 'hpe.monkeyble.monkeyble_module'` : mock appliqué.
- `🙊 Monkeyble test output passed ✔`.
- `🐵 Monkeyble - Task '…' - expected 'should_be_skipped': True. actual state: True` : état vérifié.
- `❌ MONKEYBLE ERROR ❌` + `🙊 Failed scenario: …` + le JSON du test raté (`tested_value` = valeur réelle, `expected` = attendu) : échec, le playbook s'arrête là, code 1.
- `🐵 Monkeyble - ALL TESTS PASSED ✔ - scenario: …` en fin de playbook.
- `[WARNING]: Failure using method (v2_runner_on_start) in callback plugin` : le callback a planté sur cette tâche ; ses tests et son **mock** sont sautés. À traiter comme un échec.
