---
name: ansible
description: Écrire, corriger ou relire du contenu Ansible pour ansible-core 2.17 (playbooks, rôles, inventaires, templates Jinja, collection netbox.netbox) sans utiliser de fonctionnalité plus récente. À utiliser quand on parle de playbook, rôle, Ansible, ansible-core, inventaire, module, collection, Jinja, ansible-lint, netbox.netbox ou nb_inventory.
user-invocable: true
allowed-tools:
  - read_file
  - grep
  - bash
  - ask_user_question
---

# Ansible (ansible-core 2.17)

Version cible : **ansible-core 2.17** (c'est le cœur du paquet communautaire « Ansible 10 »).
- Python du contrôleur (là où tourne `ansible-playbook`) : 3.10 à 3.12.
- Python des machines gérées : 3.7 à 3.12. Python 2.7 et 3.6 ne sont plus pris en charge sur les cibles.
- 2.17 est en fin de vie depuis novembre 2025 : ne propose pas de mise à jour toi-même, signale-le seulement si on te le demande.

Suis cette version. Si tu ne sais pas si une option, un filtre ou un module existe en 2.17, dis-le et demande (`ask_user_question`), n'invente pas.
Pour vérifier sur la machine : `ansible --version`, `ansible-doc <module>`, `ansible-doc -t filter -l`, `ansible-doc -t lookup <nom>`, `ansible-galaxy collection list`.

## Règles de base

1. Écris toujours le nom complet (FQCN) : `ansible.builtin.copy`, `ansible.builtin.template`, `ansible.builtin.command`, `netbox.netbox.netbox_device`… Jamais `copy:` tout court, jamais le mot-clé `collections:`.
2. Donne un `name:` à chaque play et à chaque tâche, en commençant par une majuscule.
3. Écris les arguments sous forme de dictionnaire YAML, pas `cle=valeur` sur une ligne.
4. Booléens YAML : `true` / `false` uniquement (pas `yes`, `no`, `True`).
5. Permissions de fichier entre guillemets : `mode: "0644"` (sinon YAML lit un nombre octal ou décimal).
6. Ne mets pas `{{ }}` dans `when`, `changed_when`, `failed_when`, `until` : ce sont déjà des expressions Jinja.

## Bonnes pratiques

- **Idempotence** : une deuxième exécution doit afficher `changed=0`. Préfère un module à une commande.
- Pas de `ansible.builtin.command` / `shell` quand un module existe (`apt`, `dnf`, `file`, `service`, `user`, `git`, `uri`…).
- Si tu dois utiliser `command` ou `shell` : ajoute `changed_when` (ou `creates` / `removes`), et `register` si tu lis le résultat. Lecture seule → `changed_when: false`.
- Teste à blanc : `ansible-playbook site.yml --check --diff`. Une tâche qui doit tourner même en check mode : `check_mode: false`. La variable `ansible_check_mode` dit si on est en check mode.
- **Secrets** : `no_log: true` sur toute tâche qui manipule un mot de passe ou un jeton ; secrets chiffrés avec `ansible-vault` ; jamais de secret en clair dans le dépôt ni dans un exemple.
- **Handlers** pour les redémarrages : `notify: Redémarrer nginx` + handler du même nom (ou `listen:`). Pour les forcer plus tôt : `ansible.builtin.meta: flush_handlers`.
- **Boucles** : `loop:` (+ `loop_control: label:` pour un affichage lisible) plutôt que `with_items` / `with_dict`. `with_*` marche encore, mais n'en ajoute pas.
- **Élévation** : `become: true` au niveau où c'est utile ; `become_user` toujours avec `become: true` au même endroit.
- Erreurs : `block` / `rescue` / `always` plutôt que `ignore_errors: true`.
- Faits : préfère `ansible_facts['distribution']` à `ansible_distribution`.

Priorité des variables (de la plus faible à la plus forte, résumé) : `defaults/` du rôle → `group_vars/all` → `group_vars/<groupe>` → `host_vars/` → faits → `vars:` du play → `vars/` du rôle → `vars:` de bloc/tâche → `set_fact` / `register` → paramètres de rôle → `-e` (extra vars, gagne toujours).
Mets les valeurs modifiables dans `defaults/main.yml`, pas dans `vars/main.yml`.

## Pièges

- `when: "{{ x }}"` : interdit. Écris `when: x`. Avec un résultat de module (`register`), un `{{ }}` dans une condition peut échouer avec « Conditional is marked as unsafe ».
- Une valeur YAML qui **commence** par `{{` doit être entre guillemets : `dest: "{{ chemin }}/app.conf"`.
- Dans une liste `when:`, une chaîne contenant `: ` devient un dictionnaire (toujours vrai) : mets des guillemets.
- Variable de chaîne utilisée comme booléen : `when: activer | bool` (une chaîne `"false"` est vraie sinon).
- Paramètre optionnel : `mode: "{{ fichier_mode | default(omit) }}"` → l'option n'est pas envoyée si la variable est absente.
- `regex_replace` : en YAML entre guillemets doubles, double les antislashs (`"\\d+"`) ; plus simple : guillemets simples (`'\d+'`). Groupes : `'\\1'`.
- N'injecte jamais de données non fiables (sorties de commande, API, saisie) dans un template Jinja construit dynamiquement ; utilise les variables directement dans l'expression.
- `vars:` doit être un dictionnaire, pas une liste de dictionnaires (avertissement en 2.17, erreur en 2.18).
- `ansible.builtin.yum` n'existe plus : il est redirigé vers `ansible.builtin.dnf`. Écris `dnf` (ou `ansible.builtin.package`).
- `include:` n'existe plus : `ansible.builtin.include_tasks` (dynamique) ou `ansible.builtin.import_tasks` (statique).

## N'existe PAS en 2.17 (ne l'utilise pas)

Venu en 2.18 :
- `loop_control: break_when:` ; `ansible.builtin.meta: end_role` ; module `ansible.builtin.mount_facts`.
- Tests `timedout` et `vaulted_file` ; commande `ansible-config validate`.
Venu en 2.19 :
- Nouveau moteur de templates et « Data Tagging » ; conditions non booléennes qui deviennent des erreurs (« broken conditionals ») ; variable `ANSIBLE_DISPLAY_TRACEBACK`.
- Filtres Jinja natifs appelables en `ansible.builtin.<nom>` ; option url-safe de `b64encode` / `b64decode`.
- Connexion SSH : `SSH_ASKPASS` par défaut (`password_mechanism`), `ansible_ssh_private_key` chargée dans un agent.
Venu en 2.20 :
- Clé `failed_when_suppressed_exception` ; dépréciation de `INJECT_FACTS_AS_VARS`.
Si un exemple trouvé ailleurs utilise un de ces éléments, réécris-le pour 2.17 ou dis que ce n'est pas possible.

## Avant de rendre la main

1. `ansible-playbook <playbook> --syntax-check`.
2. `ansible-lint` si installé (voir `references/ansible-lint.md`).
3. `ansible-playbook <playbook> --check --diff` sur une cible de test si on te le permet.
4. Ne lance jamais un playbook en vrai sur un environnement réel sans accord explicite.

## Fichiers de référence

Ces fichiers sont dans le dossier de ce skill (Vibe donne son chemin de base). Lis-les avec `read_file` quand c'est utile :
- `references/changements-2.17.md` : ce qui a changé ou disparu en 2.17 (porting guide et changelog), et ce qui arrive après. Ouvre-le pour migrer un ancien playbook ou en cas de doute sur une option.
- `references/bonnes-pratiques.md` : arborescence d'un rôle, defaults/vars, tags, block/rescue, check mode, handlers, vault. Ouvre-le pour créer ou restructurer un rôle ou un projet.
- `references/ansible-lint.md` : règles principales, profils, fichier `.ansible-lint`, `# noqa`, versions compatibles. Ouvre-le pour corriger une sortie d'ansible-lint.
- `references/netbox-netbox.md` : collection `netbox.netbox` (modules, `nb_lookup`, inventaire `nb_inventory`), versions compatibles avec NetBox 4.0 et ansible-core 2.17. Ouvre-le dès qu'il s'agit de NetBox côté Ansible.
- `references/jinja-et-filtres.md` : filtres et tests disponibles en 2.17, pièges de templating, ce qui vient de collections (`ansible.utils.ipaddr`…). Ouvre-le pour écrire un template ou une expression non triviale.
