# Piloter le controller avec Ansible : `ansible.controller` / `awx.awx`

## Quelle collection

- `ansible.controller` : collection certifiée Red Hat, fournie par Automation Hub (pas Galaxy). Sa version suit celle du controller : le correctif AAP 2.4 qui livre le controller 4.5.24 met aussi `ansible.controller` en 4.5.24. C'est le choix par défaut ici.
- `awx.awx` : même code en version communautaire, sur Galaxy. Dernière version publiée : 24.6.1 (juillet 2024). Red Hat ne garantit pas son usage avec AAP 2.4 : à réserver aux cas où `ansible.controller` n'est pas disponible.
- Les deux ont les mêmes noms de modules et d'options : seul le préfixe change (`ansible.controller.job_launch` ou `awx.awx.job_launch`).
- Ne mélange pas les deux dans un même projet. Regarde ce que le projet utilise déjà (`grep -r "awx.awx\|ansible.controller"`) et fais pareil.
- `ansible.platform` n'existe pas pour AAP 2.4 (c'est AAP 2.5).

## Connexion

Options communes à tous les modules (avec leur alias historique `tower_*`) :

| Option | Variable d'environnement | Rôle |
|---|---|---|
| `controller_host` | `CONTROLLER_HOST` (ou `TOWER_HOST`) | URL du controller |
| `controller_username` | `CONTROLLER_USERNAME` | utilisateur |
| `controller_password` | `CONTROLLER_PASSWORD` | mot de passe |
| `controller_oauthtoken` | `CONTROLLER_OAUTH_TOKEN` | token OAuth2 (à préférer) |
| `validate_certs` | `CONTROLLER_VERIFY_SSL` | vérifier le certificat |
| `request_timeout` | `CONTROLLER_REQUEST_TIMEOUT` | délai des requêtes (10 s par défaut) |
| `controller_config_file` | — | fichier de config (`host=`, `username=`, `password=`) |

- Sans rien de tout ça, les modules lisent `/etc/tower/tower_cli.cfg`, `~/.tower_cli.cfg` puis `tower_cli.cfg` du répertoire courant. Sinon ils visent `127.0.0.1`.
- Dans un job lancé PAR le controller : attache au job template un credential de type « Red Hat Ansible Automation Platform ». Il injecte `CONTROLLER_HOST`, `CONTROLLER_USERNAME`, `CONTROLLER_PASSWORD`, `CONTROLLER_OAUTH_TOKEN`, `CONTROLLER_VERIFY_SSL` (et les `TOWER_*`) : ne mets alors aucune option de connexion dans les tâches.
- Ne mets jamais un mot de passe ou un token en clair dans le playbook.
- La collection doit être dans l'EE du job ou dans `collections/requirements.yml` du projet.

## Modules utiles

Objets : `organization`, `team`, `user`, `role`, `project`, `inventory`, `inventory_source`, `host`, `group`, `credential`, `credential_type`, `credential_input_source`, `execution_environment`, `instance_group`, `job_template`, `workflow_job_template`, `workflow_job_template_node`, `schedule`, `label`, `notification_template`, `settings`, `token`.

Actions : `project_update`, `inventory_source_update`, `job_launch`, `job_wait`, `job_cancel`, `job_list`, `workflow_launch`, `workflow_node_wait`, `workflow_approval`, `ad_hoc_command`, `bulk_job_launch`, `bulk_host_create`, `export`, `import`.

Autres plugins : inventaire `controller` (hôtes d'un inventaire du controller), lookup `controller_api` (lire n'importe quel endpoint).

Avant d'utiliser une option, vérifie qu'elle existe : `ansible-doc ansible.controller.<module>` (ou `awx.awx.<module>`) en local. Si la collection n'est pas installée, dis-le au lieu de deviner.

## Exemples

Lancer un job template et attendre la fin :

```yaml
- name: Lancer le déploiement
  ansible.controller.job_launch:
    job_template: "Deploiement web"
    organization: "Exploitation"
    extra_vars:
      version: "1.4"
    limit: "web"
  register: lancement

- name: Attendre la fin (30 min max)
  ansible.controller.job_wait:
    job_id: "{{ lancement.id }}"
    timeout: 1800
  register: fin
```

- `job_launch` échoue si on passe `extra_vars` à un template qui n'a ni « Prompt on launch » sur Variables ni survey.
- Idem pour `inventory`, `credentials`, `limit`, `tags`… : ils ne servent que si le prompt correspondant est activé.
- `job_launch` a aussi `wait: true` (avec `timeout`, `interval`) si on ne veut pas de `job_wait` séparé.
- `job_wait` renvoie `status`, `elapsed`, `started`, `finished` ; il échoue si le job échoue. `job_type` permet d'attendre `project_updates`, `inventory_updates` ou `workflow_jobs`.

Créer ou mettre à jour un job template :

```yaml
- name: Job template de déploiement
  ansible.controller.job_template:
    name: "Deploiement web"
    organization: "Exploitation"
    project: "Playbooks web"
    playbook: "deploy.yml"
    inventory: "Production"
    credentials:
      - "SSH deploiement"
    execution_environment: "EE web"
    ask_variables_on_launch: true
    ask_limit_on_launch: true
    survey_enabled: true
    survey_spec: "{{ lookup('file', 'surveys/deploiement.json') }}"
    state: present
```

- Options `ask_*_on_launch` disponibles : `variables`, `limit`, `inventory`, `credential`, `tags`, `skip_tags`, `job_type`, `verbosity`, `diff_mode`, `scm_branch`, `execution_environment`, `forks`, `instance_groups`, `job_slice_count`, `labels`, `timeout`.
- `survey_spec: {}` supprime le survey.

Source d'inventaire tirée d'un fichier du projet :

```yaml
- name: Source NetBox
  ansible.controller.inventory_source:
    name: "NetBox"
    inventory: "Production"
    organization: "Exploitation"
    source: scm
    source_project: "Inventaires"
    source_path: "inventaires/netbox.yml"
    credential: "NetBox API"
    execution_environment: "EE reseau"
    overwrite: true
    update_on_launch: true
    update_cache_timeout: 300
```

- `source` accepte : `scm`, `ec2`, `gce`, `azure_rm`, `vmware`, `satellite6`, `openstack`, `rhv`, `controller`, `insights`.
- `source` est obligatoire à la création.

Synchroniser un projet puis un inventaire :

```yaml
- ansible.controller.project_update:
    project: "Playbooks web"
    organization: "Exploitation"
    wait: true

- ansible.controller.inventory_source_update:
    name: "NetBox"
    inventory: "Production"
    organization: "Exploitation"
    wait: true
```

Lire l'API via le lookup :

```yaml
- ansible.builtin.debug:
    msg: "{{ query('ansible.controller.controller_api', 'job_templates', query_params={'name__icontains': 'deploi'}) | map(attribute='name') | list }}"
```

## Bonnes habitudes

- Donne toujours `organization` quand un nom peut exister dans plusieurs organisations : sinon la recherche par nom seul échoue sur les doublons.
- Les modules d'objets sont idempotents (`state: present` / `absent`) : rejouer le playbook ne recrée rien.
- Pour gérer beaucoup d'objets, garde-les en variables (une liste par type) et boucle dessus, plutôt qu'une tâche par objet.
