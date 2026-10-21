# Changements d'ansible-core 2.17

Sources : porting guide officiel 2.17 et changelog `CHANGELOG-v2.17.rst` (branche stable-2.17), tableau de support de « Releases and maintenance ».

## Repères

| Élément | Valeur |
|---|---|
| Nom de code | « Gallows Pole » |
| Sortie (2.17.0) | 20 mai 2024 |
| Dernière version | 2.17.14 (septembre 2025) |
| Fin de vie | novembre 2025 |
| Paquet communautaire | Ansible 10.x (ex. Ansible 10.7.0 embarque ansible-core 2.17.7) |
| Python contrôleur | 3.10 – 3.12 |
| Python cibles | 3.7 – 3.12 |
| PowerShell cibles Windows | 5.1 |

## Ruptures (porting guide 2.17)

### Python sur les cibles
- Python 2.7 et Python 3.6 ne sont plus pris en charge sur les machines gérées. Il faut Python 3.7 ou plus.
- Conséquence : le module `yum` et son action sont **supprimés** et redirigés vers `dnf`.
- La découverte d'interpréteur ne contient plus de chemins codés en dur par distribution ; `python3` est la valeur par défaut.
- Pour une vieille cible sans Python 3.7+ : seul `ansible.builtin.raw` reste possible (ou installer Python avant).

### Conditions avec template imbriqué
Depuis le correctif de sécurité CVE-2023-5764 (2.16.1), une condition qui contient `{{ }}` et qui lit une donnée non fiable (résultat de module, variable `!unsafe`) peut échouer :
`Conditional is marked as unsafe, and cannot be evaluated.`
En 2.17, l'avertissement s'étend aux conditions hors tâche, par exemple `assert`.

```yaml
- name: Lire le message
  ansible.builtin.command: echo "bonjour"
  register: sortie
  changed_when: false

# À ne pas faire :
#   that: '"bonjour" in {{ sortie.stdout }}'
- name: Vérifier le message
  ansible.builtin.assert:
    that: '"bonjour" in sortie.stdout'
```

### `any_errors_fatal` et `rescue`
Quand une tâche d'un `block` avec `rescue` échoue sur un hôte et que `any_errors_fatal` est actif, la section `rescue` s'exécute sur **tous** les hôtes (car tous sont mis en échec).

## Fonctionnalités supprimées (déjà dépréciées)
- Python 2.7 / 3.6 sur les cibles (voir ci-dessus), module `yum`.
- Variable d'environnement `JINJA2_NATIVE_WARNING`.
- Option `scp_if_ssh` du plugin de connexion `ssh` (utiliser `ssh_transfer_method`).
- Support de `crypt` dans `ansible.utils.encrypt` : le filtre `password_hash` exige désormais la bibliothèque Python `passlib` sur le contrôleur.
- Anciennes API internes d'`ansible-doc`.

## Dépréciations annoncées en 2.17
- Plugins de variables « ancien style » (`get_host_vars` / `get_group_vars`) : hériter de `BaseVarsPlugin` et définir `get_vars`.
- Paramètre `required` de `get_bin_path` (module_utils).
- Imports de commodité depuis `ansible.module_utils.basic` (`PY2`, `PY3`, `iteritems`, `string_types`, `literal_eval`, etc.).
- Options globales du plugin `paramiko` : utiliser les options du plugin.
- `ansible-galaxy` : l'API Galaxy v2 est dépréciée.
- Clé `vars:` sous forme de liste de dictionnaires : avertissement (supprimé en 2.18).

## Nouveautés utiles de 2.17.0
- Filtre `regex_replace` : nouveaux paramètres `count` et `mandatory_count`.
- `import_role` : option `public` (comme `include_role`) et sous-dossiers acceptés dans les options `*_from`.
- `async` et `async_status` compatibles avec le check mode.
- Module `dnf` / `dnf5` : option `best`.
- Module `find` : option `encoding`.
- Lookup `csvfile` : option `keycol`.
- Module `user` : accepte les hachages `yescrypt`.
- Module `git` : nom `gpg_allowlist` (l'ancien `gpg_whitelist` sera déprécié).
- Configuration `LOG_VERBOSITY` (verbosité du fichier de log indépendante de l'écran) et `TARGET_LOG_INFO` (texte ajouté aux logs sur les cibles).
- `ansible-galaxy role|collection init` accepte `--extra-vars`.
- Sortie d'`ansible-doc` plus concise (`-v` pour les détails).
- Faits de montage : champs `dump` et `passno`.
- Correction : les paramètres de rôle ont de nouveau une priorité supérieure aux faits de l'hôte (comme documenté).

## Correctifs de sécurité à connaître (versions 2.17.x)
- 2.17.0 : `ANSIBLE_NO_LOG` était ignoré (CVE-2024-0690) ; rôles Galaxy et liens symboliques (CVE-2023-5115) ; perte du marquage « unsafe » (CVE-2023-5764).
- 2.17.6 : masquage `no_log` lors de la lecture de fichiers vault par `include_vars` (CVE-2024-8775) ; module `user` et liens symboliques sur la clé publique SSH (CVE-2024-9902).
- 2.17.7 : templating via `hostvars` (CVE-2024-11079).
Conseil : utiliser la dernière 2.17.x disponible (2.17.14).

## Autres changements de comportement en 2.17.x
- 2.17.5 : le mot-clé `delay` accepte un nombre décimal.
- 2.17.5 : `dnf5` accepte de nouveau `state: installed` (alias de `present`).
- 2.17.6 : le module `user` exige `force: true` pour écraser la partie publique d'une clé SSH générée.
- 2.17.8 : avertissement si un mot-clé réservé est défini via `set_fact` / `include_vars`.
- 2.17.8 : `delegate_to` vide ou indéfini donne une erreur claire.

## Après 2.17 : ce qui change (ne pas utiliser en 2.17)

### 2.18 (novembre 2024)
- Contrôleur : Python 3.11–3.13. Cibles : Python 3.8–3.13 (3.7 abandonné).
- `vars:` en liste de dictionnaires : supprimé (erreur).
- Nouveautés : `loop_control.break_when`, `meta: end_role`, module `mount_facts`, tests `timedout` et `vaulted_file`, `ansible-config validate`, options `uid_min/uid_max` (`user`) et `gid_min/gid_max` (`group`).
- `raw` via SSH sur Windows n'est plus enveloppé dans `powershell.exe`.

### 2.19 (juillet 2025)
- Contrôleur : Python 3.11–3.13. Cibles : Python 3.8–3.13. Jinja2 3.1 minimum.
- Nouveau moteur de templates + « Data Tagging » (suivi de l'origine des variables).
- Conditions dont le résultat n'est pas un booléen → erreur (« broken conditionals »).
- Templates imbriqués (multi-passes) refusés ; seules les chaînes de confiance sont rendues comme templates.
- Mode Jinja natif obligatoire (l'option de configuration n'a plus d'effet).
- Le filtre `bool` ne convertit plus les valeurs inconnues sans avertissement.
- `async_status` : utiliser les tests `is finished` / `is started` au lieu des entiers.
- SSH : `SSH_ASKPASS` devient le mécanisme par défaut au lieu de `sshpass`.
- `ANSIBLE_DISPLAY_TRACEBACK`, filtres Jinja natifs en `ansible.builtin.<nom>`.

### 2.20 (novembre 2025)
- Contrôleur : Python 3.12–3.14. Cibles : Python 3.9–3.14.
- `failed_when` qui masque une erreur : la clé `exception` devient `failed_when_suppressed_exception`.
- `INJECT_FACTS_AS_VARS` déprécié (passera à `false` en 2.24) : utiliser `ansible_facts[...]`.
- `include_vars` : `extensions` et `ignore_files` doivent être des listes.
- Galaxy API v2 supprimée ; `DEFAULT_TRANSPORT=smart` supprimé.

## Écrire du code qui tiendra la migration
Ces habitudes marchent en 2.17 **et** évitent les erreurs des versions suivantes :
- Conditions sans `{{ }}` et qui renvoient vraiment un booléen (`x | bool`, `x | length > 0`, `x is defined`).
- `ansible_facts['...']` plutôt que les faits injectés `ansible_*`.
- `vars:` toujours en dictionnaire.
- Arguments de tâche en dictionnaire, jamais `cle=valeur` mélangé avec `args:`.
- Listes pour les options de type liste.
