# Objets du controller et bonnes pratiques (AAP 2.4)

## Ordre de priorité des variables

Du plus faible au plus fort (le dernier gagne) :

1. defaults de rôle
2. variables d'inventaire dynamique
3. variables de l'inventaire du controller
4. variables de groupe du controller
5. variables d'hôte du controller
6. `group_vars` / `host_vars` du playbook
7. facts, variables enregistrées (`register`), `set_fact`
8. variables du play, `vars_files`, variables de rôle et d'include, de bloc, de tâche
9. **extra vars du job template** (champ Variables du template)
10. **valeurs par défaut du survey**
11. **extra vars données au lancement** (prompt, réponses du survey, API)

À retenir :
- Une extra var écrase tout, y compris un `set_fact` dans le playbook.
- `vars_prompt` n'est pas supporté par le controller : utilise un survey.
- Les variables du template sont fusionnées avec celles du survey.
- Les extra vars d'un prompt ou d'un survey sont `!unsafe` (Jinja non évalué). Celles écrites dans le champ Variables du template sont de confiance.

## Job templates

- Un template = un playbook d'un projet + un inventaire + des credentials + un EE.
- N'active « Prompt on launch » que sur ce qui doit vraiment changer à chaque lancement. Tout prompt non coché fait ignorer la valeur envoyée.
- Un seul credential de chaque type par template (une machine, un vault par `vault_id`, un cloud par type…).
- `limit` suit la syntaxe de `--limit` d'`ansible-playbook`.
- « Concurrent Jobs » (`allow_simultaneous`) est désactivé par défaut : les jobs d'un même template ne tournent pas en même temps.
- Job slicing (`job_slice_count` > 1) découpe l'inventaire en plusieurs jobs parallèles et crée un workflow : seulement pour des playbooks sans dépendance entre hôtes.
- Relancer un job reprend les extra vars de ce job, pas celles ajoutées depuis au template.

## Surveys

Types : Text, Textarea, Password, Multiple Choice (un choix), Multiple Choice (plusieurs), Integer, Float.

Chaque question : texte, nom de variable (sans espace), type, obligatoire ou non, longueurs min/max, valeur par défaut.

Réponse optionnelle laissée vide :
- type non texte : aucune variable envoyée ;
- Text/Textarea avec longueur min > 0 : aucune variable envoyée ;
- Text/Textarea avec longueur min = 0 : variable envoyée avec `""`.

Côté playbook, protège-toi des deux cas :

```yaml
- name: Normaliser le paramètre optionnel
  ansible.builtin.set_fact:
    branche_cible: "{{ branche | default('', true) | trim or 'main' }}"
```

(`default('', true)` remplace aussi la chaîne vide.)

- Le type Password est traité comme une donnée sensible par le controller : ne l'affiche pas avec `debug` dans le playbook.
- Multiple Choice (plusieurs) donne une liste.
- Valide les entrées dans le playbook (`ansible.builtin.assert`) : le survey ne contrôle que le type et la longueur.

## Credentials et credential types personnalisés

Utilise un type personnalisé quand un outil a besoin d'un secret qui n'a pas de type prévu (API REST, NetBox, outil maison).

Inputs (champs demandés) :

```yaml
fields:
  - id: api_url
    type: string
    label: URL de l'API
  - id: api_token
    type: string
    label: Token
    secret: true
required:
  - api_url
  - api_token
```

Injectors (ce que le job reçoit) :

```yaml
env:
  MON_OUTIL_URL: "{{ api_url }}"
  MON_OUTIL_TOKEN: "{{ api_token }}"
extra_vars:
  mon_outil_url: "{{ api_url }}"
```

Fichier temporaire (ex. config `.ini`) :

```yaml
file:
  template: "[outil]\ntoken={{ api_token }}"
env:
  MON_OUTIL_CONFIG: "{{ tower.filename }}"
```

Plusieurs fichiers : `template.cert`, `template.key`, puis `{{ tower.filename.cert }}`, `{{ tower.filename.key }}`.

Règles :
- Créer ou modifier un credential type demande les droits superutilisateur.
- Aucun nom de variable d'env ou d'extra var commençant par `ANSIBLE_`.
- Évite les collisions de noms entre credentials attachés au même template.
- Préfère l'injection en `env` pour les secrets : une extra var apparaît plus facilement dans les sorties.
- Dans le playbook, lis la variable : `lookup('ansible.builtin.env', 'MON_OUTIL_TOKEN')`.

Les credentials peuvent aussi aller chercher leur valeur dans un coffre externe (HashiCorp Vault, CyberArk, Azure Key Vault, AWS Secrets Manager, Thycotic…) via les types « Lookup ».

## Projets

- Synchronisation : bouton Sync, planification, ou « Update Revision on Launch » (avec Cache Timeout pour ne pas resynchroniser à chaque job).
- À la synchro, le controller installe :
  - `collections/requirements.yml` (si « Enable Collections Download » est actif dans les réglages Jobs) ;
  - `roles/requirements.yml`.
- Une collection du `collections/requirements.yml` du projet passe avant celle de l'EE, même plus ancienne.
- Les collections de Automation Hub ou d'un hub privé demandent un credential « Ansible Galaxy/Automation Hub API Token » attaché à l'organisation. L'ordre de ces credentials fixe l'ordre de recherche.
- « Allow Branch Override » permet à un template ou une source d'inventaire de choisir une autre branche.

Arborescence conseillée :

```
collections/requirements.yml
roles/requirements.yml
inventaires/netbox.yml
deploy.yml
group_vars/  host_vars/
```

(`group_vars/` et `host_vars/` du playbook doivent être à côté du playbook.)

## Inventaires

- Inventaire classique : hôtes et groupes saisis ou alimentés par des sources.
- Smart inventory : filtre sur les hôtes d'autres inventaires.
- Source « Sourced from a Project » : un fichier d'inventaire, un répertoire, un script exécutable ou un fichier de config de plugin pris dans un projet.

Options d'une source :
- **Overwrite** : supprime les hôtes et groupes qui ont disparu de la source.
- **Overwrite Variables** : remplace les variables au lieu de les fusionner.
- **Update on Launch** + **Cache Timeout** : resynchronise avant chaque job, au plus une fois par délai.
- **Enabled Variable / Enabled Value** : désactive les hôtes selon une variable (ex. `status.value` ≠ `active`).
- Une synchro du projet relance la synchro des sources d'inventaire qui l'utilisent.

### Exemple : NetBox via une source du projet

Dans le projet, `inventaires/netbox.yml` :

```yaml
plugin: netbox.netbox.nb_inventory
validate_certs: true
config_context: false
group_by:
  - device_roles
  - sites
device_query_filters:
  - has_primary_ip: 'true'
```

- Pas d'URL ni de token dans le fichier : le plugin lit `NETBOX_API` et `NETBOX_TOKEN` dans l'environnement.
- Le plugin pose déjà `ansible_host` à partir de l'IP primaire (option `ansible_host_dns_name: true` pour prendre le nom DNS).
- Crée un credential type personnalisé dont l'injector pose `NETBOX_API` et `NETBOX_TOKEN` en `env`, puis attache un credential de ce type à la source.
- L'EE de la source doit contenir `netbox.netbox` et ses dépendances Python (`pynetbox`, `pytz`, `packaging`).
- Les versions récentes de `netbox.netbox` demandent ansible-core 2.15 ou plus : vérifie celui de l'EE.
- Ne compte pas sur `collections/requirements.yml` du projet pour une source d'inventaire sans l'avoir vu marcher dans le log de synchro : mets la collection dans l'EE.
- Teste en local d'abord : `ansible-inventory -i inventaires/netbox.yml --graph`.

## Workflows

- Nœuds : job template, synchro de projet, synchro d'inventaire, autre workflow, approbation.
- Liens : « On Success », « On Failure », « Always ». Un nœud peut attendre plusieurs nœuds parents (convergence).
- Les variables du workflow s'ajoutent en haut de la pile de priorité, dans cet ordre : extra vars du workflow template, défauts du survey du workflow, extra vars au lancement du workflow. Elles sont combinées avec celles de chaque job template lancé.
- Inventaire du workflow : seuls les job templates qui demandent l'inventaire au lancement l'utilisent ; les autres gardent le leur.
- Passer une valeur d'un job au suivant : `ansible.builtin.set_stats` (garder `per_host: false`). En convergence, la fusion est indéfinie : utilise des clés uniques.

## Instance groups

- Choix du groupe : celui du job template, sinon de l'inventaire, sinon de l'organisation.
- Si tous les groupes associés sont pleins, le job reste en attente (`pending`) : il ne bascule pas vers `default` sauf si `default` est aussi associé.
- « Prevent Instance Group Fallback » sur le template : seuls les groupes listés sur le template sont utilisés.
- Associer un instance group à un inventaire force les jobs sur cet inventaire à tourner là (utile quand seuls ces nœuds voient le réseau cible).
