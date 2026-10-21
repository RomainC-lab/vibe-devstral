# Custom fields et GraphQL — NetBox 4.0.11

Sources : docs `customization/custom-fields.md`, `integrations/graphql-api.md`, `reference/filtering.md`, et le code v4.0.11 (`extras/models/customfields.py`, `netbox/graphql/filter_mixins.py`).

## Custom fields : types

Valeur du champ `type` (API) :

| `type` | Contenu |
|---|---|
| `text` | texte une ligne |
| `longtext` | texte long (Markdown) |
| `integer` | entier |
| `decimal` | décimal (4 décimales) |
| `boolean` | vrai/faux |
| `date` | `AAAA-MM-JJ` |
| `datetime` | date et heure ISO 8601 |
| `url` | lien |
| `json` | JSON libre |
| `select` | un choix d'un choice set |
| `multiselect` | plusieurs choix (toujours une liste) |
| `object` | un objet NetBox (type dans `related_object_type`) |
| `multiobject` | plusieurs objets NetBox |

Pas de type `color` en 4.0.11 (ajouté en 4.6).

## Custom fields : définir

- Nom : lettres, chiffres et `_` seulement (ex. `numero_ticket`). Le `label` est le libellé affiché.
- Assignation : `object_types` (liste de `app.modele`), **pas** `content_types` (nom de 3.x).
- Champs objet : `related_object_type` (**pas** `object_type`, renommé en 4.0).
- `filter_logic` : `loose` (défaut, contient), `exact`, `disabled`.
- `ui_visible` : `always`, `if-set`, `hidden`. `ui_editable` : `yes`, `no`, `hidden`. Sans effet sur les API.
- Validation : `validation_regex` (texte), `validation_minimum` / `validation_maximum` (entier).
- Autres champs : `required`, `default`, `weight`, `group_name`, `search_weight`, `is_cloneable`, `description`, `comments` (nouveau en 4.0).
- Pas de `validation_unique` ni `related_object_filter` en 4.0.11 (ajoutés en 4.1).

Créer un choice set puis un champ de sélection :

```bash
curl -X POST -H "Authorization: Token $NETBOX_TOKEN" -H "Content-Type: application/json" \
  "$NETBOX_URL/api/extras/custom-field-choice-sets/" \
  --data '{"name": "Criticité", "extra_choices": [["haute", "Haute"], ["basse", "Basse"]]}'

curl -X POST -H "Authorization: Token $NETBOX_TOKEN" -H "Content-Type: application/json" \
  "$NETBOX_URL/api/extras/custom-fields/" \
  --data '{"name": "criticite", "label": "Criticité", "type": "select",
           "object_types": ["dcim.device"], "choice_set": 1}'
```

- `extra_choices` : liste de paires `[valeur, libellé]`. `base_choices` possible : `IATA`, `ISO_3166`, `UN_LOCODE`.
- Un champ `select` ou `multiselect` doit pointer vers un choice set.

## Custom fields : lire et écrire via l'API

```json
"custom_fields": {"criticite": "haute", "ticket": "INC42", "contact_site": {"id": 3, "name": "…"}}
```

- Écriture : `"custom_fields": {"criticite": "basse"}` dans un POST/PATCH. Seules les clés envoyées changent.
- `select` : la valeur brute du choix. `multiselect` : liste de valeurs.
- `object` : l'id de l'objet (entier). `multiobject` : liste d'id. En lecture, tu reçois la représentation courte de l'objet.
- Valeur absente ou vide : `null`.

## Custom fields : filtrer

- REST : `?cf_<nom>=valeur`.
- Texte en `loose` : contient, insensible à la casse. En `exact` : égalité, et les suffixes texte (`__ic`, `__isw`, `__n`…) sont disponibles.
- Entier : `?cf_prio__gte=3`, `?cf_prio__n=0`.
- Booléen : `?cf_actif=true`.
- `filter_logic = disabled` : le filtre n'existe pas (et un filtre inconnu est ignoré sans erreur).
- pynetbox : `nb.dcim.devices.filter(cf_criticite="haute")`.
- GraphQL 4.0 : **pas** de filtre sur custom fields (arrivé en 4.3). Filtre en REST, ou côté client.

## Custom fields : dans le code Python (scripts, plugins)

```python
dev.custom_field_data["ticket"] = "INC42"   # écrire (valeur brute JSON ; pour object : l'id)
dev.full_clean()
dev.save()
dev.cf["ticket"]                             # lire la valeur désérialisée (objets, dates…)
```

- `obj.cf` est calculé une fois puis mis en cache : ne l'utilise pas pour écrire.
- Filtrer en ORM : `Device.objects.filter(custom_field_data__ticket="INC42")`.
- Jinja (export templates, webhooks) : `{{ device.cf.ticket }}`.

## GraphQL : principes en 4.0

- Moteur : Strawberry (strawberry-graphql-django 0.47) ; Graphene n'est plus utilisé depuis 4.0.
- Point d'entrée : `POST /graphql/` (navigateur GraphiQL sur la même URL). Même jeton : `Authorization: Token <jeton>`.
- Lecture seule : aucune mutation.
- Par type d'objet : `<objet>(id: N)` pour un seul, `<objet>_list` pour une liste. Ex. `device`, `device_list`, `ip_address_list`, `site_list`, `interface_list`.
- Pas de pagination GraphQL en 4.0 (arrivée en 4.3) : filtre pour limiter le volume.
- Peut être désactivé par `GRAPHQL_ENABLED = False`.

## GraphQL : filtres en 4.0

Les filtres passent dans un seul argument `filters: {…}`. Leur forme vient des filtres REST :

- Filtres déclarés (choix, objets liés par slug ou id, régions…) : valeur simple ou liste de chaînes.
  `status: "active"`, `site: ["paris", "lyon"]`, `site_id: ["6"]`, `role: "leaf"`, `region: "europe"`.
- Champs texte : objet de lookups Strawberry.
  `name: {exact: "sw1"}`, `name: {i_contains: "core"}`, `name: {starts_with: "sw"}`.
- Lookups disponibles : `exact`, `i_exact`, `contains`, `i_contains`, `in_list`, `gt`, `gte`, `lt`, `lte`, `starts_with`, `i_starts_with`, `ends_with`, `i_ends_with`, `range`, `is_null`, `regex`, `i_regex`.
- Le schéma 4.0 expose aussi `AND`, `OR`, `NOT`, `DISTINCT` (ajoutés par strawberry-django), mais NetBox ne les documente pas avant la syntaxe de 4.3. Évite-les ; sinon teste le résultat.
- Les suffixes REST (`name__ic`) ne sont pas la syntaxe GraphQL : utilise les lookups ci-dessus.
- En cas de doute sur la forme d'un filtre, ouvre GraphiQL (documentation du schéma) ou lis `<app>/graphql/filters.py` et `<app>/filtersets.py` du code installé.

```graphql
query {
  device_list(filters: {site: "paris", status: "active", name: {i_contains: "sw"}}) {
    id
    name
    role { name }
    primary_ip4 { address }
    custom_fields
    interfaces(filters: {enabled: true}) {
      name
      type
    }
  }
}
```

```bash
curl -s -H "Authorization: Token $NETBOX_TOKEN" -H "Content-Type: application/json" \
  "$NETBOX_URL/graphql/" \
  --data '{"query": "{ site_list(filters: {status: \"active\"}) { name slug } }"}'
```

- La réponse est sous `data.<nom_de_requête>` (ex. `data.site_list`).
- `custom_fields` se demande comme un champ JSON entier (pas de sous-sélection).
- `display` et `class_type` sont disponibles sur les objets.
- Attention : l'exemple curl de la doc 4.0 (`circuit_list(status:"active")`, réponse sous `circuits`) reprend l'ancienne syntaxe. Utilise `filters:`.

## GraphQL : types multiples

Pour un champ qui peut contenir plusieurs types (terminaisons de câble, objets assignés), utilise des fragments :

```graphql
{
  cable_list {
    id
    a_terminations {
      ... on InterfaceType { id name device { name } }
      ... on FrontPortType { id name }
    }
  }
}
```

Noms des types : `<Modèle>Type` (ex. `InterfaceType`, `ConsolePortType`, `CircuitTerminationType`).

## Pièges

- Ne copie pas une requête GraphQL de NetBox 3.x (arguments directs sans `filters:`) ni de 4.3+ (nouvelle forme des filtres, `pagination:`, filtres `cf_…`, `id: {exact: …}`).
- `device_role` n'existe plus : `role`.
- Un custom field invisible dans l'UI (`hidden`) reste lisible et écrivable par l'API.
