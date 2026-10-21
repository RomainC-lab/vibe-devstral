# ansible-lint avec ansible-core 2.17

Sources : documentation officielle d'ansible-lint (docs.ansible.com/projects/lint) et `pyproject.toml` des versions publiées.

## Quelle version d'ansible-lint ?

- ansible-lint est un outil séparé (`pip install ansible-lint`), il utilise l'ansible-core installé.
- Versions qui déclarent accepter ansible-core 2.17 : de la 24.x jusqu'à la **26.6.x**.
  - 25.11.x exigeait au moins ansible-core 2.17.10.
  - À partir de **26.8.0**, ansible-core 2.17 est explicitement exclu (`!=2.17.*`) : ne pas l'utiliser avec 2.17.
- Python requis par ansible-lint : 3.10 ou plus.
- Vérifier ce qui est installé : `ansible-lint --version` (affiche aussi la version d'ansible-core utilisée).
- Les règles et messages varient un peu entre versions : en cas de doute sur une règle, lance `ansible-lint -L` (liste des règles de la version installée) ou `ansible-lint -T` (liste des tags).

## Lancer

```bash
ansible-lint                       # depuis la racine du projet
ansible-lint playbooks/site.yml    # un fichier précis
ansible-lint --offline             # ne télécharge rien (utile sans internet)
ansible-lint --profile=basic       # applique un profil
ansible-lint --fix                 # corrige automatiquement ce qui peut l'être
```
Lance toujours depuis la racine du projet (là où se trouve `.ansible-lint`).
`--fix` reformate aussi le YAML : relis le diff ensuite.

## Profils

Chaque profil inclut le précédent :
1. `min` : le contenu doit pouvoir être chargé (`syntax-check`, `load-failure`, `parser-error`, `internal-error`).
2. `basic` : style et erreurs courantes (`command-instead-of-module`, `command-instead-of-shell`, `deprecated-module`, `jinja`, `key-order`, `literal-compare`, `name`, `no-free-form`, `no-jinja-when`, `no-tabs`, `partial-become`, `role-name`, `schema`, `var-naming`, `yaml`…).
3. `moderate` : lisibilité (`name[template]`, `name[casing]`).
4. `safety` : sécurité et résultats non déterministes (`latest`, `package-latest`, `risky-file-permissions`, `risky-octal`, `risky-shell-pipe`, `avoid-implicit`).
5. `shared` : pour publier (`galaxy`, `ignore-errors`, `meta-*`, `no-changed-when`, `no-handler`, `no-relative-paths`).
6. `production` : contenu certifié / AAP (`fqcn`…).

Sans profil, toutes les règles par défaut sont actives.

## Règles les plus fréquentes et correction

| Règle | Problème | Correction |
|---|---|---|
| `fqcn[action-core]` | `copy:` au lieu du nom complet | `ansible.builtin.copy:` |
| `fqcn[action]` | module de collection sans FQCN | `netbox.netbox.netbox_device:` |
| `fqcn[keyword]` | mot-clé `collections:` | le retirer, écrire les FQCN |
| `name[missing]` / `name[play]` | tâche ou play sans nom | ajouter `name:` |
| `name[casing]` | nom qui commence par une minuscule | majuscule au début |
| `name[template]` | `{{ }}` au milieu du nom | template seulement à la fin du nom |
| `no-changed-when` | `command`/`shell` sans `changed_when` | `changed_when:` ou `creates:`/`removes:` |
| `command-instead-of-module` | `command: apt-get update` | module dédié (`ansible.builtin.apt`) |
| `command-instead-of-shell` | `shell` sans besoin du shell | `ansible.builtin.command` |
| `risky-shell-pipe` | pipe sans `pipefail` | `set -o pipefail &&` + `executable: /bin/bash` |
| `risky-file-permissions` | fichier créé sans `mode` | `mode: "0644"` (ou `create: false`) |
| `risky-octal` | `mode: 644` | `mode: "0644"` |
| `yaml[truthy]` | `yes`, `no`, `True` | `true` / `false` |
| `yaml[octal-values]` | `0644` non quoté | `"0644"` |
| `yaml[line-length]` | ligne > 160 caractères | `>-` ou couper la ligne |
| `jinja[spacing]` | `{{var|filtre}}` | `{{ var \| filtre }}` |
| `no-jinja-when` | `when: "{{ x }}"` | `when: x` |
| `literal-compare` | `when: x == true` | `when: x` (ou `when: not x`) |
| `no-free-form` | `command: chdir=/tmp ls` | arguments en dictionnaire (`cmd:`, `chdir:`) |
| `partial-become` | `become_user` sans `become` | `become: true` au même niveau |
| `package-latest` | `state: latest` | `state: present` (ou version fixée) |
| `latest[git]` | `git` sans `version` | `version:` explicite |
| `no-handler` | tâche `when: resultat.changed` | `notify:` + handler |
| `ignore-errors` | `ignore_errors: true` | `failed_when:` précis ou `block/rescue` |
| `no-relative-paths` | `src: ../files/x` | chemin relatif au rôle (`src: x`) |
| `var-naming[pattern]` | `MaVariable` | `ma_variable` (minuscules, `_`) |
| `var-naming[no-role-prefix]` | variable de rôle sans préfixe | `mon_role_variable` |
| `key-order` | clés mal ordonnées | `name` en premier ; `block`/`rescue`/`always` en dernier |
| `schema[...]` | fichier non conforme au schéma | corriger la clé indiquée |

## Ignorer une règle

Sur une ligne (toujours avec une justification) :
```yaml
- name: Mettre à jour le cache
  ansible.builtin.command: apt-get update  # noqa: command-instead-of-module
  changed_when: false
```
Plusieurs règles : `# noqa: regle1 regle2`.
Une règle « par ligne » (comme `jinja[spacing]`) exige le `# noqa` sur la ligne même.
Pour un fichier entier : fichier `.ansible-lint-ignore` à côté de la config :
```
playbooks/legacy.yml package-latest
playbooks/legacy.yml yaml[line-length] skip
```
(sans `skip` : avertissement non bloquant ; avec `skip` : ignoré). `--generate-ignore` le crée (et écrase l'existant).
À éviter : le tag `skip_ansible_lint` sur une tâche (ignore toutes les règles de tâche).

## Fichier de configuration `.ansible-lint`

Noms acceptés : `.ansible-lint`, `.ansible-lint.yml`, `.ansible-lint.yaml`, `.config/ansible-lint.yml`, `.config/ansible-lint.yaml`.

```yaml
---
profile: moderate
offline: true
exclude_paths:
  - .cache/
  - collections/
skip_list:
  - yaml[line-length]
warn_list:
  - experimental
enable_list:
  - no-log-password     # règle opt-in
  - name[prefix]        # règle opt-in
mock_modules:
  - interne.outils.mon_module
mock_roles:
  - mon_role_externe
extra_vars:
  env: test
```
- `skip_list` : règle ignorée ; `warn_list` : signalée mais non bloquante ; `enable_list` : active une règle opt-in.
- `mock_modules` / `mock_roles` : quand une collection ou un rôle n'est pas installé (fréquent sans internet).
- `extra_vars` : variables nécessaires au `syntax-check`.

## yamllint

ansible-lint utilise yamllint avec sa propre configuration par défaut (longueur de ligne max 160, `---` non obligatoire, octaux interdits, `true`/`false` seulement). Un fichier `.yamllint` du projet est pris en compte s'il est compatible ; sinon ansible-lint refuse de démarrer et indique quoi corriger.

## Vault

ansible-lint exécute Ansible : s'il ne peut pas déchiffrer un fichier vault, exclure ce fichier (`exclude_paths`) ou prévoir des valeurs de remplacement pour le lint.
