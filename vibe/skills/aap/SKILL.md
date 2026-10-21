---
name: aap
description: "Écrire, relire ou dépanner ce qui tourne sur Ansible Automation Platform 2.4 (automation controller 4.5.24) : playbooks lancés par le controller, appels à son API, objets créés avec awx.awx ou ansible.controller, execution environments. À utiliser quand on parle d'AAP, Ansible Automation Platform, automation controller, Tower/AWX, job template, workflow, survey/questionnaire, extra vars, execution environment (EE), ansible-builder, API du controller, awx.awx, ansible.controller."
user-invocable: true
allowed-tools:
  - read_file
  - grep
  - bash
  - ask_user_question
---

# Ansible Automation Platform (controller 4.5.24)

Version cible : automation controller 4.5.24, soit AAP 2.4 (correctif AAP 2.4 de juillet 2025). Ce n'est PAS AAP 2.5 (controller 4.6).

Suis cette version. Si tu ne sais pas si une chose existe ici, dis-le et demande avec `ask_user_question`. N'invente ni module, ni option, ni endpoint d'API.

## Concepts clés

- **Organisation** : regroupe utilisateurs, équipes, projets, inventaires, credentials. Tout objet vit dans une organisation.
- **Projet** : un dépôt Git (ou autre SCM) qui contient les playbooks. Le controller le synchronise (« project sync ») avant de s'en servir.
- **Inventaire** : liste d'hôtes et de groupes. Il peut avoir des **sources** (cloud, fichier ou script du projet, plugin d'inventaire) qui le remplissent à la synchro.
- **Credential** : secret stocké chiffré (machine/SSH, SCM, vault, cloud, registry…). Un **credential type** personnalisé définit des champs (inputs) et la façon de les injecter (injectors : variables d'env, extra vars, fichiers).
- **Job template** : projet + playbook + inventaire + credentials + EE + options. C'est ce qu'on lance.
- **Workflow job template** : enchaîne job templates, synchros de projet/inventaire et approbations, avec des branches succès/échec/toujours.
- **Survey (questionnaire)** : questions posées au lancement ; chaque réponse devient une extra var.
- **Prompt on launch** : case par champ (variables, limit, inventaire, credentials, tags…) qui autorise à le changer au lancement.
- **Execution environment (EE)** : image de conteneur où tourne `ansible-playbook` (ansible-core + collections + libs Python + paquets système).
- **Instance group** : groupe de nœuds qui exécutent les jobs. Ordre de choix : job template, puis inventaire, puis organisation.

## Usage courant

1. Pousse le playbook dans le dépôt du projet, puis synchronise le projet.
2. Déclare les collections dans `collections/requirements.yml` et les rôles dans `roles/requirements.yml` à la racine du projet.
3. Crée ou mets à jour le job template (UI, API ou module `job_template`).
4. Lance : UI, `POST /api/v2/job_templates/<id>/launch/`, ou module `job_launch` + `job_wait`.
5. Lis le résultat : statut du job puis sortie (`/api/v2/jobs/<id>/stdout/?format=txt`).

## Pièges

- Les extra vars passées au lancement gagnent sur tout (inventaire, playbook, `set_fact`…). Ne compte pas sur une variable d'inventaire si un survey ou un lancement la redéfinit.
- Les `extra_vars` envoyées au lancement sont ignorées si le job template n'a ni « Prompt on launch » sur Variables ni survey activé. L'API le signale dans `ignored_fields` ; le module `job_launch` échoue.
- Survey : une question texte optionnelle laissée vide avec une longueur min de 0 envoie une chaîne vide `""`, pas une variable absente. Avec une longueur min > 0, ou pour un type non texte, rien n'est envoyé. Teste avec `| default(...)` ET le cas `""`.
- Les extra vars venues d'un prompt ou d'un survey sont marquées `!unsafe` : le Jinja dedans n'est pas évalué.
- L'EE doit contenir les collections, les libs Python (ex. `pynetbox`, `netaddr`, `jmespath`) et les paquets système dont le playbook a besoin. Sinon : erreur d'import au job, pas au sync.
- Une collection de `collections/requirements.yml` du projet passe AVANT celle de l'EE, même si elle est plus ancienne.
- Un playbook ou un fichier modifié dans Git n'est vu qu'après une synchro du projet (manuelle, planifiée ou « Update Revision on Launch »).
- Un script d'inventaire dans le projet doit être exécutable (`chmod +x` commité), sinon `[Errno 13] Permission denied`.
- Relancer un job réutilise ses extra vars d'origine, pas celles ajoutées depuis au job template.
- Pas d'accès à Internet au travail : ne propose pas d'installer depuis Galaxy sans demander quel hub ou miroir interne est utilisé.

## N'existe PAS (ou pas comme ça) en 2.4

Ces choses sont propres à AAP 2.5 ; ne les utilise pas ici :
- **Platform gateway** et UI unifiée (« Automation Execution », « Automation Decisions »…) : en 2.4, le controller, le hub et EDA ont chacun leur UI et leur authentification.
- API du controller sous `/api/controller/v2/` et API de la gateway sous `/api/gateway/v1/` : en 2.4, l'API du controller est sous `/api/v2/`.
- Tokens créés par la gateway : en 2.4, les tokens OAuth2 se créent sur le controller (`/api/v2/tokens/` ou `/api/v2/users/<id>/personal_tokens/`).
- Collection `ansible.platform` (utilisateurs, équipes, organisations via la gateway) : en 2.4, tout passe par `ansible.controller` / `awx.awx`.
- EDA avec event streams et UI commune : en 2.4, EDA controller 1.0.x est un composant séparé.
- Rôles sous `/api/controller/v2/role_definitions` etc. : en 2.4, rôles via `/api/v2/roles/` et `/api/v2/<objet>/<id>/object_roles/`.

## Fichiers de référence

Ils sont dans `references/` sous le répertoire de base de ce skill (Vibe le donne). Lis-les avec `read_file` quand il le faut :
- `references/api-controller.md` : appeler l'API REST (token, lancer un job, suivre son statut, lire la sortie, pagination, filtres), en curl ou Python `requests`.
- `references/collection-ansible-controller.md` : écrire un playbook qui pilote le controller (modules `job_template`, `job_launch`, `job_wait`, `inventory_source`…), variables de connexion, choix `ansible.controller` / `awx.awx`.
- `references/objets-et-bonnes-pratiques.md` : concevoir job templates, surveys, credential types personnalisés (injectors), inventaires dynamiques depuis le projet (ex. NetBox), ordre de priorité des variables.
- `references/execution-environments.md` : comprendre ou construire un EE (`execution-environment.yml` version 3, ansible-builder 3, images ee-minimal / ee-supported, ajout d'une collection ou d'une lib Python).
