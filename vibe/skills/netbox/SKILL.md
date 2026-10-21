---
name: netbox
description: Référence précise de NetBox 4.0.11 (API REST, GraphQL, pynetbox, scripts personnalisés, custom fields, plugins) pour écrire du code juste sans Internet. À utiliser quand on parle de NetBox, API NetBox, pynetbox, script personnalisé, custom field, plugin NetBox, GraphQL NetBox ou d'un appel à /api/dcim/….
user-invocable: true
allowed-tools:
  - read_file
  - grep
  - bash
  - ask_user_question
---

# NetBox 4.0.11

Version cible : NetBox 4.0.11 (Django 5.0, Django REST Framework 3.15, GraphQL Strawberry, Python 3.10 à 3.12, PostgreSQL 12+, Redis 4.0+).

## Règles

1. Suis cette version. Si tu ne sais pas si une chose existe en 4.0.11, dis-le et demande avec `ask_user_question`. N'invente ni champ, ni filtre, ni endpoint.
2. Beaucoup d'exemples en ligne visent 4.1 à 4.7 ou 3.x. Vérifie chaque nom avec la section « N'existe PAS » ci-dessous.
3. Si le code NetBox est installé localement (souvent `/opt/netbox/netbox/`), lis-le avec `grep` avant de deviner un nom de champ ou de filtre.
4. Sur une instance qui répond, vérifie plutôt que de supposer : `GET /api/status/`, `OPTIONS` sur un endpoint, ou `/api/schema/swagger-ui/`.
5. Jamais de jeton, d'URL ou de nom de serveur réel dans le code ou les exemples : lis-les depuis des variables d'environnement.

## Ce qui change en 4.0 (par rapport à 3.7)

- Python 3.8 et 3.9 abandonnés ; Django 5.0.
- Device : le champ et le filtre `device_role` / `device_role_id` sont supprimés. Utilise `role` / `role_id`.
- Rapports (reports) supprimés : ils deviennent des scripts personnalisés. `/api/extras/reports/` n'existe plus.
- `content_types` devient `object_types` (custom fields, custom links, export templates, saved filters, event rules) ; filtre `object_type` / `object_type_id`.
- CustomField : `object_type` renommé `related_object_type`.
- `/api/extras/content-types/` devient `/api/extras/object-types/`.
- Paramètre REST `?fields=a,b,c` (nouveau) ; le mode `?brief=` inclut maintenant `description`.
- GraphQL passe de Graphene à Strawberry : la syntaxe des filtres change (`filters: {…}`).
- Location : `parent` / `parent_id` ne renvoient que les enfants directs ; `ancestor` / `ancestor_id` pour toute la descendance.
- Plugins : imports depuis `netbox.plugins` (plus `extras.plugins`), `FieldSet` pour les formulaires, `brief_fields` + `nested=True` dans les serializers.
- Admin Django désactivé par défaut (`DJANGO_ADMIN_ENABLED`). Depuis 4.0.2, `LOGIN_REQUIRED` vaut True par défaut.

## Usage courant

API REST :
- Authentification : en-tête `Authorization: Token <jeton>` (jeton de 40 caractères hexadécimaux). Ajoute `Content-Type: application/json` pour écrire.
- Garde le `/` final dans les URL (`/api/dcim/devices/123/`), sinon redirection 302.
- Pagination : `limit` / `offset` ; réponse `{count, next, previous, results}`. Par défaut 50 (`PAGINATE_COUNT`), plafond 1000 (`MAX_PAGE_SIZE`). Suis `next` jusqu'à `null`.
- Filtres : `?status=active&site=paris` ; plusieurs valeurs du même filtre = OU ; suffixes `__n`, `__ic`, `__isw`, `__gte`, `__empty`… ; custom field : `?cf_<nom>=valeur`.
- Réduire la réponse : `?brief=1` (vue minimale) ou `?fields=id,name,status`. Sur devices et VM : `?exclude=config_context`.
- Écriture : un objet lié se donne par son id (`"site": 6`) ou par un dict d'attributs uniques. Choix : la valeur brute (`"status": "active"`).
- En masse : POST d'une liste ; PATCH ou DELETE sur l'endpoint de liste avec `[{"id": …}, …]`. Tout ou rien.

pynetbox (version 7.4.1 pour NetBox 4.0) :
```python
import os, pynetbox
nb = pynetbox.api(os.environ["NETBOX_URL"], token=os.environ["NETBOX_TOKEN"])
dev = nb.dcim.devices.get(name="sw1")          # None si absent
for d in nb.dcim.devices.filter(site="paris", status="active"):
    print(d.name, d.role.name)
dev.custom_fields["ticket"] = "INC42"; dev.save()
```

Custom fields :
- Lecture/écriture via `custom_fields` (dict) dans le JSON de l'objet. Filtre REST `cf_<nom>`.
- Création via `/api/extras/custom-fields/` avec `object_types: ["dcim.device"]` et `type` (`text`, `integer`, `select`…).

Script personnalisé minimal :
```python
from dcim.models import Site
from extras.scripts import Script, StringVar, ObjectVar

class Renommer(Script):
    class Meta:
        name = "Renommer un site"
        commit_default = False

    site = ObjectVar(model=Site)
    nom = StringVar(max_length=100)

    def run(self, data, commit):
        site = data["site"]
        site.snapshot()
        site.name = data["nom"]
        site.full_clean()
        site.save()
        self.log_success(f"Site renommé : {site}", site)
```

GraphQL : `POST /graphql/`, même jeton. Requêtes `device(id: 1)` et `device_list(filters: {…})`. Lecture seule.

## Pièges

- `?brief=false` ou `?brief=0` active quand même le mode brief : toute valeur non vide l'active. Omets le paramètre.
- `?limit=0` ne renvoie tout que si `MAX_PAGE_SIZE` vaut 0 ou None ; sinon tu reçois `MAX_PAGE_SIZE` objets. Pagine toujours.
- Un filtre au nom inexistant est ignoré sans erreur : tu reçois tous les objets. Vérifie le nom du filtre.
- Les filtres `site`, `role`, `tenant`, `region`… attendent un slug ; pour un id, utilise `site_id`, `role_id`…
- PUT exige l'objet complet ; préfère PATCH.
- Dans un script, `log_*(message, obj)` : message d'abord. L'ancien ordre des reports (`obj, message`) est faux pour `Script`.
- Un script n'apparaît que s'il est enregistré comme module (UI : téléversement ou fichier d'une data source).
- Plugin : `max_version = "4.0"` refuse 4.0.11 (comparaison de versions complète). Écris `"4.0.99"` ou laisse vide.

## N'existe PAS en 4.0.11

Ne l'utilise pas ; si on te le demande, signale que c'est d'une version plus récente.
- 4.1 : `display_url` dans les serializers ; champ `event_types` des event rules (4.0 : `type_create`, `type_update`, `type_delete`, `type_job_start`, `type_job_end`) ; `vid_ranges` des VLAN groups (4.0 : `min_vid` / `max_vid`) ; rack types, circuit groups, notifications/abonnements ; `/api/core/object-changes/` (4.0 : `/api/extras/object-changes/`) ; `validation_unique` et `related_object_filter` des custom fields ; `PluginTemplateExtension.models` (4.0 : `model`, au singulier).
- 4.2 : objets MAC address (`/api/dcim/mac-addresses/`, `primary_mac_address`) — en 4.0 `mac_address` est un simple champ de l'interface ; `scope` sur Prefix/Cluster (4.0 : `site`) ; `termination` sur CircuitTermination (4.0 : `site` / `provider_network`) ; virtual circuits, Q-in-Q, VLAN translation.
- 4.3 : nouvelle syntaxe de filtres GraphQL, filtres GraphQL sur custom fields, pagination GraphQL ; `parent` sur Service (4.0 : `device` / `virtual_machine`) ; `groups` sur Contact (4.0 : `group`) ; `/api/extras/tagged-objects/`.
- 4.4 : `changelog_message` ; `/api/core/object-types/` (4.0 : `/api/extras/object-types/`) ; `DecimalVar` pour les scripts.
- 4.5 : jetons v2 et en-tête `Authorization: Bearer nbt_…` ; champ `owner` ; profils de câble ; `/api/authentication-check/`.
- 4.6 et suivantes : paramètre de pagination `start`, ETag / `If-Match`, `add_tags` / `remove_tags`.

## Fichiers de référence

Le dossier `references/` est dans le répertoire de base du skill (donné par Vibe au chargement). Ouvre-les avec `read_file` selon le besoin :
- `references/api-rest.md` : appels HTTP, filtres et suffixes, brief/fields, pagination, écritures en masse, objets liés, jetons.
- `references/pynetbox.md` : écrire un script Python client avec pynetbox 7.4.1.
- `references/scripts-personnalises.md` : écrire ou corriger un script personnalisé (variables, Meta, logs, tests, exécution UI/API/CLI).
- `references/custom-fields-et-graphql.md` : créer/filtrer des custom fields, écrire une requête GraphQL Strawberry 4.0.
- `references/changements-4.0.md` : migrer du code 3.x vers 4.0, ou vérifier qu'une fonction n'est pas d'une version plus récente.
- `references/plugins.md` : développer ou porter un plugin NetBox 4.0.
