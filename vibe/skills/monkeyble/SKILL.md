---
name: monkeyble
description: "Documentation de Monkeyble 1.7.1 (framework de tests de bout en bout pour playbooks et rôles Ansible, collection hpe.monkeyble et CLI monkeyble), utilisé avec ansible-core 2.17 et Python 3.11. À utiliser quand on écrit, corrige ou lance un test Monkeyble, un scénario monkeyble_scenarios, un fichier monkeyble.yml, test_input, test_output, un mock monkeyble_module, should_fail, should_be_skipped, should_be_changed, la commande monkeyble test, ou quand on veut tester un rôle qui appelle netbox.netbox sans toucher NetBox, ou lancer ces tests dans la CI GitLab."
user-invocable: true
allowed-tools:
  - read_file
  - grep
  - bash
  - ask_user_question
---

# Monkeyble 1.7.1

## Version
- Version cible : **Monkeyble 1.7.1** (sortie le 2026-04-24, la dernière sur PyPI et sur Galaxy).
- Deux morceaux à installer, de la même version :
  - la **collection Ansible `hpe.monkeyble`** : le callback `hpe.monkeyble.monkeyble_callback` (le vrai moteur des tests) et le module de simulation `hpe.monkeyble.monkeyble_module` ;
  - le **paquet Python `monkeyble`** (pip) : seulement la commande `monkeyble` (`test`, `list`). Il ne contient ni le callback ni le module.
- Python : le paquet pip demande **Python 3.11 ou plus** (`>=3.11,<4.0` depuis la 1.6.0). Il n'installe pas Ansible : ansible-core doit déjà être là.
- ansible-core 2.17 : la collection déclare `requires_ansible: '>=2.11'`. Le projet ne teste officiellement que les versions d'Ansible 11 (core 2.18) et 12 (core 2.19), **pas 2.17**. Un essai complet a été fait avec ansible-core 2.17.14 + Python 3.11.18 + netbox.netbox 3.21.0 : test_input, test_output, mock, should_fail, should_be_skipped, should_be_changed et `monkeyble test` marchent (voir `references/exemple-netbox.md`).
- Si tu ne sais pas si une option existe dans Monkeyble 1.7.1 : dis-le et demande avec `ask_user_question`. N'invente jamais une clé : la liste complète est ci-dessous.
- Tu n'as pas internet : cette skill et ses fichiers `references/` sont ta seule documentation de Monkeyble.

## Ce que fait Monkeyble
Un callback Ansible qui, pendant un vrai `ansible-playbook`, pour chaque tâche citée par son **nom** dans le scénario :
1. vérifie les **arguments** envoyés au module, après templating Jinja (`test_input`) ;
2. remplace le module par un **mock** qui renvoie un dictionnaire choisi (`mock`), pour ne rien créer pour de vrai ;
3. vérifie l'**état** de la tâche (`should_be_changed`, `should_be_skipped`, `should_fail`) ;
4. vérifie le **résultat** de la tâche (`test_output`).
Pas d'infrastructure à créer : c'est complémentaire de Molecule (qui, lui, vérifie l'état final d'une vraie machine).

## Toutes les clés d'un scénario
```yaml
monkeyble_scenarios:               # dictionnaire de scénarios, passé en extra var (-e @fichier)
  nom_du_scenario:                 # choisi par -e monkeyble_scenario=nom_du_scenario
    name: "Description lisible"
    extra_vars: {}                 # au niveau du scénario (depuis 1.5.0)
    tasks_to_test:
      - task: "Nom exact de la tâche"   # obligatoire, comparé au nom APRÈS templating
        role: "nom_du_role"        # filtre facultatif
        play: "nom_du_play"        # filtre facultatif
        extra_vars: {}             # au niveau de la tâche, gagne sur celui du scénario
        test_input: [ ... ]        # liste de { assert_xxx: { arg_name, expected } }
        test_output: [ ... ]       # liste de { assert_xxx: { result_key, expected } }
        should_be_changed: true
        should_be_skipped: false
        should_fail: false
        mock:
          config:
            hpe.monkeyble.monkeyble_module:
              consider_changed: true
              result_dict: { ... }
monkeyble_shared_tasks: [ ... ]    # mêmes entrées que tasks_to_test, valables dans tous les scénarios
```
Tests disponibles (les seuls) : `assert_equal`, `assert_not_equal`, `assert_in`, `assert_not_in`, `assert_true`, `assert_false`, `assert_is_none`, `assert_is_not_none`, `assert_list_equal`, `assert_dict_equal`.

## Usage courant
```bash
# un scénario à la main
ANSIBLE_CONFIG=monkeyble.cfg ansible-playbook playbook.yml \
  -e "@tests/monkeyble/scenarios.yml" -e "monkeyble_scenario=site_planifie"
# toute la suite décrite dans monkeyble.yml (monkeyble_test_suite)
ANSIBLE_CONFIG=monkeyble.cfg monkeyble test
ANSIBLE_CONFIG=monkeyble.cfg monkeyble test --limit site_planifie site_actif
monkeyble list
```
- Code de retour : 0 si tout passe, 1 si un test échoue. C'est ce que lit la CI.
- Mets le callback dans un fichier de config **à part** (`monkeyble.cfg`), choisi par `ANSIBLE_CONFIG`. Jamais dans l'`ansible.cfg` utilisé par AAP (voir Pièges).
- Mets `jinja2_native = True` dans ce fichier (obligatoire avant ansible-core 2.19, donc avec 2.17).
- Sur un module qui touche NetBox, une API ou une machine : `test_input` + `mock` sur la même tâche. Les arguments sont vérifiés, puis le module est remplacé : NetBox n'est jamais appelé.

## Pièges (tous vérifiés en 1.7.1 avec ansible-core 2.17)
- **Variables de `defaults/` du rôle dans un `test_input`** : le callback échoue (`'pop_site' is undefined`), Ansible n'affiche qu'un `[WARNING]: Failure using method (v2_runner_on_start)`, et **le mock n'est pas appliqué : le vrai module tourne** (bug ouvert #63). Contournement : passe aussi `roles/<role>/defaults/main.yml` en extra var (`-e @…` ou dans `extra_vars:` de `monkeyble.yml`). Cherche toujours ce WARNING dans la sortie.
- Sans `jinja2_native = True`, un `set_fact` de `{{ x.id }}` donne la chaîne `"42"` et `assert_equal: expected: 42` échoue.
- Callback activé sans `-e monkeyble_scenario=…` : le playbook s'arrête avec `'monkeyble_scenario' need to be passed as extra_vars` (code 1).
- Collection installée par Galaxy : écris les noms complets `hpe.monkeyble.monkeyble_callback` et `hpe.monkeyble.monkeyble_module`. Les noms courts ne marchent qu'avec l'installation par clone git (`library` / `callback_plugins` dans la config) ; sinon `The module monkeyble_module was not found` ou callback jamais lancé.
- Le premier test raté **arrête le playbook** (pas de rapport des tâches suivantes).
- `should_fail: true` et la tâche échoue : le playbook s'arrête là avec le code 0 (sauf `ignore_errors` ou `rescue`). Les tâches suivantes ne sont pas testées. Bug ouvert #64 : `should_fail` sur la dernière tâche d'un `rescue:` est compté en échec.
- La tâche est trouvée par son **nom** : donne des noms uniques. Un nom avec `{{ }}` est comparé après templating.
- Les `lookup`/`query` (`netbox.netbox.nb_lookup`…) ne sont **pas** simulés, même avec un `mock` sur la tâche (essayé : le lookup tourne quand même). Contournement `when: x is not defined` + valeur en `-e` : voir `references/mock.md`.
- Les `extra_vars` de Monkeyble ne changent que les arguments du module des tâches listées, pas un `when:` ni les autres tâches. Pour changer une variable partout : un fichier passé en `-e`.

## N'existe PAS dans Monkeyble 1.7.1
- Pas de sortie JUnit ni de rapport de fichier : seulement la sortie console, le tableau final et le code de retour.
- Pas de filtre par tag, pas de mode « tout simuler par défaut », pas de mode enregistrement.
- Pas de motifs (`*.yml`) dans les `extra_vars` de `monkeyble.yml` : un chemin par ligne.
- Pas d'option de `monkeyble test` pour passer d'autres arguments à `ansible-playbook` (seulement `-c/--config`, `--limit`, `-v/--version`) : utilise les variables d'environnement `ANSIBLE_*`.
- Pas de simulation de lookup, de filtre ni de connexion.

## Fichiers de référence
Vibe donne le dossier de cette skill quand elle est chargée (« Base directory »). Lis le fichier utile avec `read_file` avant de répondre :
- `references/installation.md` : pip, collection Galaxy ou hors ligne, `monkeyble.cfg`, versions, vérifier l'installation.
- `references/scenarios-et-cli.md` : fichier `monkeyble.yml` (`monkeyble_test_suite`, `monkeyble_global_extra_vars`, `MONKEYBLE_CONFIG`), scénarios, partage de config, `monkeyble_shared_tasks`, filtres `role`/`play`, `extra_vars`, commandes `test` et `list`, sortie.
- `references/tests.md` : `test_input`, `test_output` (`result_key`), les 10 assertions avec exemples, boucles, états `should_*`, block/rescue.
- `references/mock.md` : `mock`, `monkeyble_module`, `consider_changed`, `result_dict`, module de mock maison, ce qui ne peut pas être simulé.
- `references/exemple-netbox.md` : exemple complet et testé d'un rôle qui appelle `netbox.netbox` (site + équipement), scénarios, `monkeyble.yml`, sortie attendue.
- `references/ci-gitlab-et-aap.md` : job GitLab CI, image d'exécution officielle (en core 2.19 : attention), réseau fermé, ce qui marche ou non avec AAP 2.4 / automation controller.
