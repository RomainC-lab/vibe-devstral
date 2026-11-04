# Monkeyble 1.7.1 : installation

## En bref
- Deux morceaux, de la même version 1.7.1 :
  - **collection `hpe.monkeyble`** (Galaxy) : callback `monkeyble_callback` + module `monkeyble_module`. Indispensable.
  - **paquet pip `monkeyble`** : la commande `monkeyble` (`test`, `list`). Facultatif (on peut lancer `ansible-playbook` à la main), mais pratique pour la CI.
- Le paquet pip ne dépend que de `tabulate` (>=0.9,<0.10) et `pyyaml` (>=6.0.2,<7). Il n'installe **pas** Ansible : installe ansible-core toi-même, dans le même environnement Python.
- Python 3.11 ou plus pour le paquet pip 1.6.0 et suivants. Avec Python 3.10 il faudrait une vieille version (1.4.x) : ne le propose pas sans demander.
- La collection n'a aucune dépendance (`dependencies: {}`) et déclare `requires_ansible: '>=2.11'`.

## Versions et compatibilité
| Monkeyble | Date | Ce qui compte |
|---|---|---|
| 1.7.1 | 2026-04-24 | correctif d'import du callback (à prendre plutôt que 1.7.0) |
| 1.7.0 | 2026-04-23 | image d'exécution officielle ; le mock ne se fait plus écraser par les infos d'un fichier existant (`dest`/`path`) ; plus de mutation des `extra_vars` entre tâches |
| 1.6.0 | 2026-04-20 | prise en charge d'Ansible 12 (core 2.19) ; Python >= 3.11 |
| 1.5.0 | 2025-10-10 | boucles, `rescue`, `extra_vars` au niveau du scénario |
| 1.4.4 | 2025-09 | le mock marche avec `module_defaults` |
| 1.4.0 | 2023-03 | `monkeyble list`, `monkeyble test --limit` |
| 1.2.0 | 2022-12 | `should_failed` renommé `should_fail` (casse les vieux fichiers) |

ansible-core 2.17 : pas dans la matrice de tests du projet (qui teste Ansible 11 = core 2.18 et 12 = core 2.19 avec Python 3.11), mais le code prévoit l'ancien moteur de templates (avant 2.19) et un essai complet avec **ansible-core 2.17.14 + Python 3.11.18** est passé. Si un comportement surprend, pense d'abord à cette version non testée par le projet.

## Installer (poste ou CI avec accès à PyPI et Galaxy)
```bash
python3.11 -m venv .venv-monkeyble
. .venv-monkeyble/bin/activate
pip install "ansible-core>=2.17,<2.18" "monkeyble==1.7.1"
ansible-galaxy collection install -p ./collections "hpe.monkeyble:==1.7.1" "netbox.netbox:==3.21.0"
monkeyble -v          # affiche « Monkeyble 1.7.1 »
```
Ou dans un `requirements.yml` du projet :
```yaml
collections:
  - name: hpe.monkeyble
    version: "1.7.1"
```
Avec pipx : `pipx inject ansible --include-apps monkeyble`.

## Installer sans internet (réseau du travail)
- Sur une machine qui a le droit, télécharge les fichiers puis copie-les :
  ```bash
  pip download "monkeyble==1.7.1" -d paquets/           # + tabulate et pyyaml
  ansible-galaxy collection download "hpe.monkeyble:==1.7.1" -p collections-hors-ligne/
  ```
- Puis sur la machine fermée :
  ```bash
  pip install --no-index --find-links paquets/ monkeyble==1.7.1
  ansible-galaxy collection install collections-hors-ligne/hpe-monkeyble-1.7.1.tar.gz -p ./collections
  ```
- Si l'entreprise a un miroir PyPI ou un Automation Hub privé, demande son adresse à l'utilisateur ; ne l'invente pas, ne l'écris pas dans un dépôt public.

## Le fichier de config Ansible dédié (`monkeyble.cfg`)
Installation par Galaxy (le cas normal) :
```ini
[defaults]
collections_path = ./collections
roles_path = ./roles
callbacks_enabled = hpe.monkeyble.monkeyble_callback
; obligatoire avant ansible-core 2.19 (donc en 2.17) pour garder les types (null, nombres)
jinja2_native = True
```
Installation par clone git du dépôt monkeyble (noms courts) :
```ini
[defaults]
library = /chemin/monkeyble/plugins/modules
module_utils = /chemin/monkeyble/plugins/module_utils
callback_plugins = /chemin/monkeyble/plugins/callback
callbacks_enabled = monkeyble_callback
jinja2_native = True
```
- Recopie dans `monkeyble.cfg` les autres réglages utiles de l'`ansible.cfg` du projet (`roles_path`, `collections_path`, `inventory`…) : `ANSIBLE_CONFIG` n'en lit qu'un seul.
- On peut aussi tout passer par l'environnement : `ANSIBLE_CALLBACKS_ENABLED=hpe.monkeyble.monkeyble_callback ANSIBLE_JINJA2_NATIVE=True ANSIBLE_COLLECTIONS_PATH=./collections` (essayé : marche).
- Ne mets pas `callbacks_enabled = hpe.monkeyble.monkeyble_callback` dans l'`ansible.cfg` normal du projet : sans `monkeyble_scenario`, chaque playbook s'arrêterait en erreur (voir `ci-gitlab-et-aap.md`).
- `MONKEYBLE_CONFIG` n'est **pas** un réglage Ansible : c'est le chemin du fichier `monkeyble.yml` de la CLI (voir `scenarios-et-cli.md`).

## Vérifier que ça marche
- La sortie doit contenir `🐵 Starting Monkeyble callback 1.7.1` au début de chaque play. Sinon le callback n'est pas chargé (mauvais `ANSIBLE_CONFIG`, nom court, `collections_path`). La CLI le détecte : « Seems that Monkeyble callback has not started. Check your Ansible config. »
- `ansible-doc -t callback hpe.monkeyble.monkeyble_callback` répond « missing documentation » : c'est normal (le callback n'a pas de doc intégrée), ce n'est pas une erreur d'installation.
- `ansible-galaxy collection list hpe.monkeyble` donne la version installée.

## Erreurs fréquentes
- `ModuleNotFoundError: No module named 'ansible'` en lançant `monkeyble` : ansible-core n'est pas dans le même environnement Python que la CLI.
- `The module monkeyble_module was not found in configured module paths` : nom court avec une collection Galaxy → écris `hpe.monkeyble.monkeyble_module`.
- `Failed to import the required Python library (pynetbox)` alors qu'un mock est prévu : le mock n'a pas été appliqué. Regarde le WARNING `Failure using method (v2_runner_on_start)` juste avant (souvent une variable de `defaults/` inconnue dans un `test_input`).
