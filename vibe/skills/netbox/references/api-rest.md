# API REST NetBox 4.0.11

Source : docs `integrations/rest-api.md`, `reference/filtering.md` et code de la v4.0.11.

## Bases

- Racine : `https://<hôte>/api/`. Une app par préfixe : `circuits`, `core`, `dcim`, `extras`, `ipam`, `tenancy`, `users`, `virtualization`, `vpn`, `wireless`, `plugins`.
- Chaque modèle a une vue liste (`/api/dcim/devices/`) et une vue détail (`/api/dcim/devices/123/`).
- Le `/` final est obligatoire ; sans lui : redirection 302.
- Autres points utiles : `/api/status/` (versions, plugins, workers), `/api/schema/` (OpenAPI), `/api/schema/swagger-ui/` (doc interactive), `/graphql/`.
- L'en-tête de réponse `API-Version` donne `majeur.mineur` (ici `4.0`).
- L'en-tête `X-Request-ID` permet de retrouver les changements : `GET /api/extras/object-changes/?request_id=<uuid>`.

## Authentification

- En-tête : `Authorization: Token <jeton>`. Le jeton fait 40 caractères hexadécimaux.
- Un jeton peut être en lecture seule (`write_enabled` faux), expirer, ou être limité à des IP (`allowed_ips`).
- Créer un jeton par identifiant/mot de passe : `POST /api/users/tokens/provision/` avec `{"username": …, "password": …}` (sans jeton).
- Sans jeton valide : 403 `"Authentication credentials were not provided."`. Depuis 4.0.2, `LOGIN_REQUIRED` vaut True par défaut : même la lecture exige un jeton.

```bash
curl -s -H "Authorization: Token $NETBOX_TOKEN" \
     -H "Accept: application/json" \
     "$NETBOX_URL/api/dcim/sites/?status=active"
```

## Lire

- Liste paginée : `{"count": N, "next": url|null, "previous": url|null, "results": [...]}`.
- `limit` et `offset` : `?limit=100&offset=200`. Défaut : `PAGINATE_COUNT` (50).
- Plafond : `MAX_PAGE_SIZE` (1000 par défaut). Un `limit` plus grand est ramené au plafond.
- `?limit=0` : tout d'un coup seulement si `MAX_PAGE_SIZE` vaut 0 ou None ; sinon renvoie `MAX_PAGE_SIZE` objets.
- Pour tout lire : boucle sur `next` jusqu'à `null`.

```python
import os, requests
s = requests.Session()
s.headers["Authorization"] = f"Token {os.environ['NETBOX_TOKEN']}"
url = f"{os.environ['NETBOX_URL']}/api/dcim/devices/?limit=1000&site=paris"
devices = []
while url:
    r = s.get(url, timeout=30)
    r.raise_for_status()
    page = r.json()
    devices += page["results"]
    url = page["next"]
```

## Réduire la réponse

- `?brief=1` : représentation minimale (`id`, `url`, `display`, nom/slug, `description`…). Marche sur liste et détail.
- Toute valeur non vide active brief (`?brief=false` aussi). Pour le désactiver, n'envoie pas le paramètre.
- `?fields=id,name,status` (nouveau en 4.0) : seulement ces champs. Les requêtes SQL sont réduites d'autant.
- `?exclude=config_context` : sur devices et VM, retire le config context rendu (plus rapide en liste).
- `?ordering=name` ou `?ordering=-created` ; plusieurs champs séparés par des virgules.

## Filtrer

- `?champ=valeur`. Plusieurs filtres différents = ET. Même filtre répété = OU (`?site=a&site=b`).
- Exception : `?tag=a&tag=b` = objets ayant les deux tags (ET).
- Recherche libre : `?q=texte`.
- Objets liés : `site`, `region`, `tenant`, `role`, `manufacturer`… attendent un **slug** ; `site_id`, `role_id`… attendent un **id**.
- Valeur nulle : la plupart des filtres d'objets liés acceptent `null` (ex. `?tenant_id=null`). Si tu n'es pas sûr pour un filtre précis, teste-le.
- Choix possibles d'un champ : `OPTIONS` sur l'endpoint liste, puis `.actions.POST.<champ>.choices` (le jeton doit pouvoir faire POST).
- Un filtre inconnu est ignoré sans erreur : tous les objets reviennent. Vérifie toujours le nom.

### Suffixes (lookups)

Champs numériques : `__n` (différent), `__lt`, `__lte`, `__gt`, `__gte`, `__empty` (booléen).

Champs texte : `__n`, `__ic` (contient), `__nic`, `__isw` (commence par), `__nisw`, `__iew` (finit par), `__niew`, `__ie` (égal, sans casse), `__nie`, `__empty`. Tous insensibles à la casse sauf `__n`.

Clés étrangères : seulement `__n` (ex. `?group_id__n=12`).

```
GET /api/ipam/vlans/?vid__gte=100&vid__lt=200
GET /api/dcim/devices/?name__ic=core&status__n=offline
GET /api/dcim/interfaces/?device_id=123&ordering=name
```

### Custom fields

- Préfixe `cf_` : `?cf_ticket=INC42`.
- Texte en mode « loose » (défaut) : correspondance partielle insensible à la casse. Mode « exact » : égalité stricte. Mode « disabled » : pas de filtre.
- Entiers, dates : suffixes possibles (`?cf_priorite__gte=3`).

### Changements de filtres en 4.0

- Devices : `role` / `role_id` (plus `device_role`).
- Locations : `parent` / `parent_id` = enfants directs ; `ancestor` / `ancestor_id` = toute la descendance. Même logique pour les autres modèles imbriqués (régions, groupes de sites…).
- Custom fields, custom links, export templates, saved filters, event rules : `object_type` / `object_type_id` (plus `content_types`).

## Écrire

- `POST` liste = créer ; `PATCH` détail = modifier partiellement ; `PUT` = remplacer (tous les champs obligatoires) ; `DELETE` détail = supprimer (204 sans corps).
- Préfère `PATCH`.
- Choix : envoie la valeur brute (`"status": "active"`), pas le dict `{value, label}` reçu en lecture.
- Objet lié par id : `"site": 6`. Ou par attributs uniques : `"rack": {"site": {"name": "DC1"}, "name": "R204"}`. Si 0 ou plusieurs objets correspondent : erreur de validation.
- Relation générique : deux champs, `assigned_object_type` (`"dcim.interface"` ou `"virtualization.vminterface"`) et `assigned_object_id`.
- Tags : liste d'id ou de dicts (ex. `[{"name": "prod"}]`).
- Custom fields : `"custom_fields": {"ticket": "INC42"}`.

```bash
curl -s -X POST -H "Authorization: Token $NETBOX_TOKEN" \
  -H "Content-Type: application/json" "$NETBOX_URL/api/dcim/devices/" \
  --data '{"name": "sw1", "device_type": 3, "role": 2, "site": 6, "status": "planned"}'
```

Champs obligatoires d'un device : `device_type`, `role`, `site` (le `name` peut être nul).

### En masse (tout ou rien)

```bash
# créer plusieurs objets
--data '[{"name": "S1", "slug": "s1"}, {"name": "S2", "slug": "s2"}]'      # POST /api/dcim/sites/
# modifier plusieurs objets
--data '[{"id": 10, "status": "active"}, {"id": 11, "status": "retired"}]' # PATCH /api/dcim/sites/
# supprimer plusieurs objets
--data '[{"id": 10}, {"id": 11}]'                                          # DELETE /api/dcim/sites/
```

Si un seul objet échoue, rien n'est appliqué.

## Endpoints spéciaux utiles

- `/api/ipam/prefixes/<id>/available-ips/` et `/available-prefixes/` : GET pour lister, POST pour allouer.
- `/api/ipam/ip-ranges/<id>/available-ips/`, `/api/ipam/vlan-groups/<id>/available-vlans/`.
- `/api/dcim/interfaces/<id>/trace/` : chemin de câble.
- `/api/dcim/devices/<id>/render-config/` : POST pour rendre le config template.
- `/api/extras/scripts/` : lister et lancer les scripts (voir `scripts-personnalises.md`).

## Erreurs fréquentes

- 400 : validation (champ obligatoire manquant, choix invalide, objet lié introuvable). Lis le JSON renvoyé : clé = champ fautif.
- 403 : jeton absent, invalide, en lecture seule, ou permission manquante.
- 404 : id inexistant, ou objet invisible pour ce jeton (permissions par contraintes).
- 302 : `/` final oublié.
