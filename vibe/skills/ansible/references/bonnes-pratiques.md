# Bonnes pratiques Ansible (ansible-core 2.17)

## Arborescence d'un projet

```
projet/
├── ansible.cfg
├── inventaire/
│   ├── hosts.yml
│   ├── group_vars/
│   │   ├── all.yml
│   │   └── web.yml
│   └── host_vars/
│       └── web01.yml
├── collections/requirements.yml
├── roles/
└── site.yml
```

`collections/requirements.yml` :
```yaml
---
collections:
  - name: netbox.netbox
    version: ">=3.19.0,<3.22.0"
  - name: ansible.utils
```
Installation : `ansible-galaxy collection install -r collections/requirements.yml`.
Sans internet : installer depuis une archive `.tar.gz` déjà téléchargée (`ansible-galaxy collection install ./netbox-netbox-3.20.0.tar.gz`).

## Arborescence d'un rôle

```
roles/mon_role/
├── defaults/main.yml      # valeurs par défaut, modifiables (priorité la plus faible)
├── vars/main.yml          # constantes internes (priorité forte, difficiles à surcharger)
├── tasks/main.yml         # point d'entrée
├── handlers/main.yml
├── templates/             # fichiers .j2 pour ansible.builtin.template
├── files/                 # fichiers copiés tels quels
├── meta/main.yml          # dépendances, infos galaxy
├── meta/argument_specs.yml # validation des paramètres du rôle
└── README.md
```
Squelette : `ansible-galaxy role init roles/mon_role`.

Règles :
- Préfixe toutes les variables du rôle par son nom : `mon_role_port`, `mon_role_paquets`.
- Ce que l'utilisateur doit pouvoir changer → `defaults/`. Ce qui ne doit pas changer → `vars/`.
- Découpe `tasks/` en fichiers (`install.yml`, `config.yml`) appelés depuis `main.yml`.
- Garde le rôle centré sur une seule chose.

Validation des paramètres (`meta/argument_specs.yml`) :
```yaml
---
argument_specs:
  main:
    short_description: Installe et configure l'application
    options:
      mon_role_port:
        type: int
        default: 8080
        description: Port d'écoute
      mon_role_admin_mail:
        type: str
        required: true
```

## Appeler un rôle

```yaml
- name: Configurer les serveurs web
  hosts: web
  become: true
  roles:
    - role: mon_role
      vars:
        mon_role_port: 8443
```
Ou dans les tâches :
- `ansible.builtin.import_role` : statique, résolu à la lecture du playbook ; les tags et `when` s'appliquent à toutes les tâches du rôle.
- `ansible.builtin.include_role` : dynamique, résolu à l'exécution ; utile dans une boucle ou une condition. Les tags posés dessus ne s'appliquent qu'à l'include (utiliser `apply:` pour les propager).
- Même logique pour `import_tasks` / `include_tasks`.

## Handlers

```yaml
# tasks/main.yml
- name: Déployer la configuration
  ansible.builtin.template:
    src: app.conf.j2
    dest: /etc/app/app.conf
    mode: "0644"
  notify: Redémarrer app

# handlers/main.yml
- name: Redémarrer app
  ansible.builtin.service:
    name: app
    state: restarted
```
- Un handler ne s'exécute qu'une fois, à la fin du play (ou à `ansible.builtin.meta: flush_handlers`).
- `listen: "redemarrage app"` permet de notifier plusieurs handlers avec un seul sujet.
- Si une tâche échoue après une notification, le handler n'est pas exécuté sauf avec `--force-handlers` (ou `force_handlers: true`).

## Tags

```yaml
- name: Installer les paquets
  ansible.builtin.package:
    name: "{{ mon_role_paquets }}"
    state: present
  tags: [install]
```
- `--tags install`, `--skip-tags config`, `--list-tags`, `--list-tasks`.
- Tags spéciaux : `always` (s'exécute toujours sauf `--skip-tags always`), `never` (ne s'exécute que si demandé explicitement).

## block / rescue / always

```yaml
- name: Mise à jour avec retour arrière
  block:
    - name: Déployer la nouvelle version
      ansible.builtin.unarchive:
        src: app.tar.gz
        dest: /opt/app
  rescue:
    - name: Restaurer l'ancienne version
      ansible.builtin.copy:
        src: /opt/app.bak/
        dest: /opt/app/
        remote_src: true
        mode: preserve
  always:
    - name: Nettoyer
      ansible.builtin.file:
        path: /tmp/app.tar.gz
        state: absent
```
- `become`, `when`, `tags` posés sur le `block` s'appliquent à toutes ses tâches.
- Dans `rescue`, `ansible_failed_task` et `ansible_failed_result` décrivent l'erreur.

## Check mode et diff

- `ansible-playbook site.yml --check --diff` : simule et montre les différences.
- `check_mode: false` sur une tâche : elle s'exécute vraiment même en `--check` (ex. lecture d'un état avec `command`).
- `check_mode: true` : la tâche est toujours simulée.
- `when: not ansible_check_mode` pour sauter une tâche en simulation.
- `diff: false` sur une tâche qui afficherait un secret.

## Commandes et idempotence

```yaml
- name: Lire la version installée
  ansible.builtin.command:
    cmd: /opt/app/bin/app --version
  register: app_version
  changed_when: false
  check_mode: false

- name: Initialiser la base une seule fois
  ansible.builtin.command:
    cmd: /opt/app/bin/app init
    creates: /var/lib/app/.initialise
```
- `command` ne passe pas par un shell : pas de `|`, `>`, `&&`. Si c'est nécessaire, `shell` avec `set -o pipefail` (et `executable: /bin/bash`).
- `failed_when` pour définir soi-même l'échec : `failed_when: resultat.rc not in [0, 2]`.

## Secrets

- `ansible-vault create group_vars/all/vault.yml`, `ansible-vault edit …`, `ansible-vault encrypt_string 'valeur' --name 'db_password'`.
- Convention : variable chiffrée `vault_db_password`, référencée en clair `db_password: "{{ vault_db_password }}"`.
- Exécution : `--ask-vault-pass` ou `--vault-password-file <fichier>` (fichier hors du dépôt).
- `no_log: true` sur les tâches qui manipulent un secret (y compris en boucle : sinon les items sont affichés).

## Inventaire YAML

```yaml
---
all:
  children:
    web:
      hosts:
        web01.exemple:
        web02.exemple:
      vars:
        http_port: 8080
    db:
      hosts:
        db01.exemple:
          ansible_host: 192.0.2.10
```
Vérifier : `ansible-inventory -i inventaire/ --graph` ou `--list`.

## Délégation et exécution locale

- `delegate_to: localhost` : la tâche tourne sur le contrôleur mais avec les variables de l'hôte courant.
- `run_once: true` : une seule exécution pour tout le groupe (ex. appel d'API).
- Les modules qui parlent à une API (NetBox, etc.) se lancent en général avec `delegate_to: localhost` ou dans un play `hosts: localhost` + `connection: local`.

## Performance

- `gather_facts: false` si le play n'utilise pas de faits.
- Liste de paquets en un seul appel (`name: [a, b, c]`) plutôt qu'une boucle.
- `serial:` pour déployer par lots, `max_fail_percentage:` pour arrêter tôt.

## Tests de rôles
Molecule est un outil séparé (non inclus dans ansible-core). Ne le propose que s'il est déjà utilisé dans le projet (présence d'un dossier `molecule/`).
