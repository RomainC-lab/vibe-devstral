# Changements de NetBox 4.0 et versions suivantes

Sources : `docs/release-notes/version-4.0.md` (tag v4.0.11), `docs/plugins/development/migration-v4.md`, et les notes de version 4.1 à 4.7 (branche main).

## Pile logicielle de 4.0.11

- Python 3.10, 3.11 ou 3.12 (3.8 et 3.9 abandonnés en 4.0 ; 3.12 ajouté).
- Django 5.0 (5.0.9 dans `requirements.txt`), Django REST Framework 3.15.2, django-filter 24.2.
- strawberry-graphql 0.239.2 et strawberry-graphql-django 0.47.1 (remplacent Graphene).
- psycopg 3, PostgreSQL 12 ou plus, Redis 4.0 ou plus.
- 4.0.11 est la dernière version de la branche 4.0 (sortie le 2024-09-03, même jour que 4.1.0).

## Ruptures de 4.0 (par rapport à 3.7)

Modèles, filtres, API :
- Device : attribut, champ d'API et filtres `device_role` / `device_role_id` supprimés. Utilise `role` / `role_id` (renommé dès 3.6).
- Location : `parent` / `parent_id` = enfants directs seulement ; `ancestor` / `ancestor_id` = toute la descendance. Même logique pour les autres modèles imbriqués.
- CustomField : `content_types` → `object_types` ; `object_type` → `related_object_type`.
- CustomLink, ExportTemplate, SavedFilter, EventRule : `content_types` → `object_types`.
- ImageAttachment et ContactAssignment : `content_type` → `object_type`.
- Filtres correspondants : `content_types` → `object_type`, `content_type_id` → `object_type_id`.
- `/api/extras/content-types/` → `/api/extras/object-types/`.
- `/api/extras/reports/` supprimé.
- Mode brief : `description` incluse partout où le modèle en a une.

Rapports :
- Les rapports (classe `Report`, `REPORTS_ROOT`) sont abandonnés. Ils sont convertis en scripts à la mise à jour.
- Les méthodes `test_*` fonctionnent maintenant dans `Script`.

GraphQL :
- Graphene remplacé par Strawberry. La forme des filtres change : `xxx_list(filters: {…})`.

Code Python interne :
- Module `utilities.utils` supprimé (fonctions réparties dans d'autres modules de `utilities`).
- `NullableCharField` supprimé : `CharField(null=True)`.
- Filtre de template `annotated_date` et tag `annotated_now` supprimés.
- Import des ressources de plugin : seulement `netbox.plugins` (plus `extras.plugins`).
- `extras.webhooks_worker.process_webhook()` → `extras.webhooks.send_webhook()`.
- `BootstrapMixin` (formulaires) supprimé.
- Utilisateurs et groupes : modèles propres à NetBox (`users.User`, `users.Group`), pas ceux de Django. Utilise `django.contrib.auth.get_user_model()`.
- `ContentType` : NetBox utilise le proxy `ObjectType` (`core.ObjectType`). Exception : la ForeignKey d'une clé générique (GFK) pointe toujours vers `contenttypes.ContentType`.
- Les migrations antérieures à 3.7 sont fusionnées : passer de < 3.7 à 4.0 exige d'abord 3.7.

Configuration :
- Interface d'admin Django désactivée par défaut ; `DJANGO_ADMIN_ENABLED = True` pour la réactiver.
- `ENABLE_LOCALIZATION` et les anciens paramètres de format de date supprimés.
- Depuis 4.0.2 : `LOGIN_REQUIRED` vaut True par défaut ; paramètre `ENABLE_TRANSLATION` ajouté.

## Nouveautés de 4.0 utiles au code

- Paramètre REST `?fields=a,b` pour choisir les champs renvoyés.
- Comptages d'objets liés annotés automatiquement dans l'API.
- VirtualChassis : champ `members` dans l'API. Location : champ `facility`.
- Users et Groups : champ `permissions` dans l'API.
- CustomField : champ `comments`.
- Scripts : chaque script est un objet en base ; logs paginés et filtrables.
- Formulaires : `FieldSet`, `InlineFields`, `TabbedGroups`, `ObjectAttribute` (`utilities.forms.rendering`).
- Validateurs personnalisés : reçoivent la requête courante ; attributs liés par chemin pointé.
- Image attachments possibles sur les VM.

## Ajouté en 4.0.x (correctifs)

- 4.0.2 : `LOGIN_REQUIRED` vrai par défaut, `ENABLE_TRANSLATION`.
- 4.0.6 : `log_*()` des scripts appelable sans message.
- Plusieurs ajouts de types d'interface et de filtres (ex. devices filtrables par cluster et cluster group, composants par statut du device).

## Ce qui n'existe PAS en 4.0.11

Signale-le si on te demande ces éléments.

4.1 (2024-09) :
- `display_url` dans les réponses REST.
- EventRule : `event_types` (liste) remplace `type_create`, `type_update`, `type_delete`, `type_job_start`, `type_job_end`, qui existent encore en 4.0.
- VLANGroup : `vid_ranges` remplace `min_vid` / `max_vid` (présents en 4.0).
- Unité des disques VM passée de Go à Mo (en 4.0 : `disk` et `VirtualDisk.size` en Go).
- Changelog déplacé : `/api/core/object-changes/` (en 4.0 : `/api/extras/object-changes/`).
- Rack types (`/api/dcim/rack-types/`), circuit groups, modules imbriqués, notifications et abonnements, champ `serial` des VM.
- CustomField : `validation_unique`, `related_object_filter`.
- `CustomValidator.validate()` doit accepter `request` (déjà accepté en 4.0, obligatoire en 4.1).
- Plugins : `PluginTemplateExtension.models` (liste) ; en 4.0 c'est `model` (un seul). Jobs de plugin améliorés.
- Les serializers « Nested… » sont dépréciés en 4.1 et supprimés en 4.2 ; ils existent encore en 4.0.

4.2 (2025-01) :
- Objets MAC address (`/api/dcim/mac-addresses/`, `primary_mac_address`) ; en 4.0 `mac_address` est un champ modifiable de l'interface.
- Prefix et Cluster : `scope_type` / `scope_id` remplacent `site` (en 4.0 : `site`).
- CircuitTermination : `termination_type` / `termination_id` remplacent `site` / `provider_network`.
- Virtual circuits, Q-in-Q, politiques de traduction VLAN, statut des inventory items.
- Django 5.1 ; admin Django totalement retiré ; PostgreSQL 13 minimum.

4.3 (2025-05) :
- Nouvelle syntaxe des filtres GraphQL, filtres GraphQL sur custom fields, pagination GraphQL.
- Service : `parent` générique remplace `device` / `virtual_machine` (présents en 4.0).
- Contact : `groups` (plusieurs) remplace `group` (un seul en 4.0).
- `/api/extras/tagged-objects/`, `/api/extras/table-configs/`, module type profiles, rôles de device hiérarchiques, `mark_populated` des IP ranges, `sync_interval` des data sources.
- `ALLOW_TOKEN_RETRIEVAL` passe à False par défaut (True en 4.0).

4.4 (2025-09) :
- `changelog_message` dans les écritures REST.
- `/api/core/object-types/` (en 4.0 : `/api/extras/object-types/`).
- `DecimalVar` dans les scripts ; `self.logger` des jobs ; plateformes imbriquées ; config context profiles.

4.5 (2026-01) :
- Jetons v2 : `Authorization: Bearer nbt_<clé>.<jeton>`. En 4.0, seul `Authorization: Token <jeton>` existe.
- Champ `owner` (propriété des objets), profils de câble, mappings de ports avant/arrière.
- `/api/authentication-check/`.
- Python 3.12 minimum ; `load_yaml()` / `load_json()` retirés des scripts (présents en 4.0).

4.6 (2026-05) et 4.7 (2026-09) :
- Pagination par curseur `?start=`, ETag / `If-Match`, `add_tags` / `remove_tags`, type de custom field couleur, VM types, rack groups.
- 4.7 : valeurs des custom fields `select` renvoyées comme `{value, label}` (en 4.0 : la valeur brute) ; `?exclude=config_context` ignoré (actif en 4.0).
