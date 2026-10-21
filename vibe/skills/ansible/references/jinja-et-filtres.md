# Jinja, filtres et tests (ansible-core 2.17)

Source : code des plugins `filter`, `test` et `lookup` de la branche stable-2.17, porting guides.
ansible-core 2.17 demande Jinja2 3.0 ou plus sur le contrôleur. Les templates sont évalués sur le contrôleur, jamais sur la cible.

Vérifier sur la machine : `ansible-doc -t filter -l`, `ansible-doc -t test -l`, `ansible-doc -t filter ansible.builtin.combine`.

## Où mettre des accolades

- Valeur d'option, `vars`, `msg`, templates `.j2` : `"{{ variable }}"`.
- `when`, `changed_when`, `failed_when`, `until`, `assert.that` : expression **sans** accolades (`when: paquets | length > 0`).
- Une valeur YAML qui commence par `{{` doit être entre guillemets.
- Texte long : `>-` (replié) ou `|` (lignes conservées).

## Filtres d'ansible-core 2.17 (`ansible.builtin.*`)

Données et structures :
- `combine` : fusionne des dictionnaires ; `combine(autre, recursive=true)` pour les sous-dictionnaires ; `list_merge='append'` (ou `replace`, `keep`, `prepend`, `append_rp`, `prepend_rp`).
- `dict2items` / `items2dict` : dictionnaire ↔ liste de `{key, value}`.
- `flatten` (option `levels`), `subelements`, `extract`, `zip`, `zip_longest`.
- `unique`, `union`, `intersect`, `difference`, `symmetric_difference`.
- `product`, `permutations`, `combinations`, `rekey_on_member`.
- `mandatory` : erreur si la variable n'est pas définie (message possible : `mandatory('message')`).
- `ternary('si_vrai', 'si_faux')`.
- `type_debug` : affiche le type Python (débogage).

Formats :
- `to_json`, `to_nice_json`, `from_json`, `to_yaml`, `to_nice_yaml`, `from_yaml`, `from_yaml_all`.
- `b64encode`, `b64decode`, `to_uuid`, `comment`.
- `urldecode`, `urlsplit` (le filtre `urlencode` vient de Jinja).

Texte et regex :
- `regex_search`, `regex_findall`, `regex_replace`, `regex_escape`, `quote` (échappement shell), `split`.
- `regex_replace` en 2.17 : nouveaux paramètres `count` et `mandatory_count`.

Chemins (côté contrôleur) : `basename`, `dirname`, `expanduser`, `expandvars`, `path_join`, `realpath`, `relpath`, `splitext`, `normpath`, `commonpath`, `fileglob`, `win_basename`, `win_dirname`, `win_splitdrive`.

Booléens, dates, hachage :
- `bool` : convertit `"yes"`, `"true"`, `"1"`, `"on"` → `true`.
- `to_datetime`, `strftime`.
- `hash('sha256')`, `checksum`, `md5`, `sha1`, `password_hash('sha512')` (exige `passlib` en 2.17).
- `vault` / `unvault`.

Maths : `log`, `pow`, `root`, `random`, `shuffle`, `human_readable`, `human_to_bytes`.

## Filtres Jinja natifs (sans préfixe en 2.17)

`default` (alias `d`), `join`, `map`, `select`, `reject`, `selectattr`, `rejectattr`, `first`, `last`, `length`, `sort`, `min`, `max`, `sum`, `lower`, `upper`, `capitalize`, `replace`, `trim`, `int`, `float`, `string`, `list`, `dictsort`, `groupby`, `batch`, `indent`, `urlencode`.
En 2.17, ces filtres s'écrivent **sans** `ansible.builtin.` (le nom complet n'existe qu'à partir de 2.19).

## Tests (`is …`)

- Résultats de tâche : `succeeded`, `failed`, `changed`, `skipped`, `reachable`, `unreachable`, `finished`, `started`.
- Chaînes : `match` (début de chaîne), `search` (n'importe où), `regex`.
- Versions : `version('2.0', '>=')` (alias `version_compare`).
- Valeurs : `truthy`, `falsy`, `vault_encrypted`, `defined`, `undefined`, `none`, `string`, `number`, `mapping`, `iterable`, `sameas`.
- Ensembles : `subset`, `superset`, `contains`, `any`, `all`, `nan`.
- Fichiers (sur le contrôleur !) : `file`, `directory`, `link`, `exists`, `abs`, `same_file`, `mount`.
- URL : `uri`, `url`, `urn`.

Les tests `timedout` et `vaulted_file` n'existent pas en 2.17 (2.18).

## Lookups utiles (`ansible.builtin.*`)

`file`, `template`, `env`, `pipe`, `password`, `vars`, `varnames`, `first_found`, `fileglob`, `lines`, `csvfile`, `ini`, `url`, `unvault`, `sequence`, `dict`, `subelements`, `inventory_hostnames`.
- `lookup(...)` renvoie une chaîne (éléments joints par des virgules) ; `query(...)` renvoie toujours une liste → préfère `query` pour `loop`.
- Les lookups s'exécutent sur le contrôleur.

## Hors ansible-core (collections)

| Besoin | Où | Prérequis |
|---|---|---|
| Adresses IP : `ipaddr`, `ipv4`, `ipv6`, `ipsubnet`, `ipmath`, `nthhost`, `network_in_usable`, `cidr_merge`, `hwaddr`, `macaddr` | collection `ansible.utils` (`ansible.utils.ipaddr`…) | bibliothèque Python `netaddr` |
| Comparer / filtrer des clés : `keep_keys`, `remove_keys`, `replace_keys`, `to_paths`, `get_path`, `index_of`, `validate` | `ansible.utils` | — |
| Requêtes JMESPath : `json_query` | `community.general.json_query` | `jmespath` |

L'ancien `ipaddr` de `ansible.netcommon` est remplacé par celui d'`ansible.utils` : écris `ansible.utils.ipaddr`. Le paquet Ansible 10.7.0 embarque `ansible.utils` 4.1.0.

## Exemples

```yaml
- name: Construire la liste des noms actifs
  ansible.builtin.set_fact:
    noms_actifs: "{{ serveurs | selectattr('actif') | map(attribute='nom') | list }}"

- name: Fusionner les réglages
  ansible.builtin.set_fact:
    reglages: "{{ reglages_defaut | combine(reglages_site, recursive=true) }}"

- name: Option facultative
  ansible.builtin.user:
    name: "{{ utilisateur }}"
    shell: "{{ utilisateur_shell | default(omit) }}"

- name: Extraire un numéro de version
  ansible.builtin.set_fact:
    version_app: "{{ sortie.stdout | regex_search('(\\d+\\.\\d+)', '\\1') | first }}"

- name: Boucler sur un dictionnaire
  ansible.builtin.debug:
    msg: "{{ item.key }} = {{ item.value }}"
  loop: "{{ ports | dict2items }}"
```

## Pièges de templating

- **Accolades dans les conditions** : `when: "{{ x }}"` est déconseillé ; avec une donnée non fiable (résultat de `register`), cela peut échouer (« Conditional is marked as unsafe »).
- **Chaînes vraies** : `"false"` (chaîne) est vrai dans une condition. Utilise `| bool`.
- **Types** : en 2.17 (mode non natif par défaut), un template renvoie une chaîne, sauf si le texte obtenu ressemble à une liste, un dictionnaire ou vaut exactement `True` / `False` (il est alors converti). `"{{ 1 + 1 }}"` donne la chaîne `"2"` : convertis à l'usage avec `| int`, `| bool`.
- **`default` et chaîne vide** : `default('x')` ne remplace que l'indéfini ; pour aussi remplacer `''` / `none` : `default('x', true)`.
- **`omit`** : seulement comme valeur d'option de module (`default(omit)`), pas dans une chaîne composée.
- **Regex** : dans des guillemets doubles YAML, chaque `\` doit être doublé (`"\\d"`) ; en guillemets simples, non (`'\d'`). Pour un groupe en remplacement : `'\\1'`.
- **`regex_search`** renvoie `none` s'il n'y a pas de correspondance : prévoir `default('')` avant de l'utiliser.
- **`map` / `select`** renvoient un générateur : terminer par `| list`.
- **`{% %}` dans un `.j2`** : contrôler les espaces avec `{%-` et `-%}` ; pour du texte qui contient `{{`, utiliser `{% raw %}…{% endraw %}`.
- **Données non fiables** : ne jamais construire une expression Jinja à partir d'une valeur externe (sortie de commande, API, saisie). Référence la variable directement. Marque une chaîne qui ne doit jamais être interprétée avec `!unsafe`.
- **Variables magiques** : `hostvars['hote']['var']`, `groups['web']`, `inventory_hostname`, `ansible_check_mode`, `role_path`, `playbook_dir`.
