# pynetbox avec NetBox 4.0.11

Source : README et code de pynetbox, tag v7.4.1.

## Quelle version

- Tableau de compatibilité officiel : pynetbox **7.3.4** testé avec NetBox 4.0.0, **7.4.1** testé avec NetBox 4.0.6. La 7.5.0 vise NetBox 4.1 à 4.4.
- Pour NetBox 4.0.11 : épingle `pynetbox==7.4.1`.
- Dépendances : `requests` (>=2.20, <3) et `packaging`. Python 3.10 à 3.12 annoncé.
- Il n'y a pas d'Internet : vérifie ce qui est installé avec `pip show pynetbox`. Si la version diffère, signale-le.

## Connexion

```python
import os
import pynetbox

nb = pynetbox.api(
    os.environ["NETBOX_URL"],          # sans /api, il est ajouté
    token=os.environ["NETBOX_TOKEN"],
    threading=False,                   # True : pages lues en parallèle dans all()/filter()
)
nb.http_session.verify = os.environ.get("NETBOX_CA", True)  # certificat interne
print(nb.version)    # "4.0"
print(nb.status())   # contenu de /api/status/
```

- Paramètres de `pynetbox.api()` en 7.4.1 : `url`, `token`, `threading`. Rien d'autre.
- Le jeton est envoyé en `Authorization: Token <jeton>`.
- Pour un délai, des retries ou un proxy : remplace `nb.http_session` par ta propre `requests.Session()`.
- Apps disponibles : `circuits`, `core`, `dcim`, `extras`, `ipam`, `tenancy`, `users`, `virtualization`, `vpn`, `wireless`, `plugins`.
- Endpoint : nom de l'URL avec `_` au lieu de `-` : `nb.dcim.device_types`, `nb.ipam.ip_addresses`, `nb.extras.custom_fields`.
- Plugin : `nb.plugins.<nom_plugin>.<endpoint>`.

## Lire

```python
dev = nb.dcim.devices.get(42)                 # par id ; None si 404
dev = nb.dcim.devices.get(name="sw1")          # None si 0 ; ValueError si plusieurs
devs = nb.dcim.devices.filter(site="paris", role="leaf", status="active")
devs = nb.dcim.devices.filter(name__ic="core")          # suffixes REST
devs = nb.dcim.devices.filter(role=["leaf", "spine"])   # plusieurs valeurs = OU
devs = nb.dcim.devices.filter("sw")                     # recherche libre (q)
devs = nb.dcim.devices.filter(cf_ticket="INC42")        # custom field
tout = nb.dcim.sites.all()
n = nb.dcim.devices.count(site="paris")
```

- `filter()` et `all()` renvoient un `RecordSet` paresseux : il se lit une seule fois. Pour réutiliser : `list(...)`.
- La pagination est gérée automatiquement. `limit=` / `offset=` sont possibles ; `offset` sans `limit` lève `ValueError`.
- `None` comme valeur de filtre est envoyé comme `null`.
- Filtre mal nommé ou valeur au mauvais format (nom au lieu de slug) : **aucune erreur**, tu reçois tous les objets. Vérifie avec `count()`.
- `site`, `role`, `tenant`… : slug. `site_id`, `role_id`… : id.

## Les Record

- Attributs : `dev.name`, `dev.site.name`, `dev.status.value`, `dev.status.label`.
- Les objets liés sont des Record « courts » ; un attribut absent déclenche un GET complet automatique.
- `dict(dev)` : dict complet. `dev.serialize()` : dict prêt pour une écriture (objets liés réduits à leur id).
- `dev.custom_fields` : dict simple.
- Choix : en lecture, `dev.status` a `.value` et `.label` ; en écriture, donne la valeur brute (`"active"`).

## Créer

```python
site = nb.dcim.sites.create(name="Paris", slug="paris", status="active")
dev = nb.dcim.devices.create(
    name="sw1", device_type=3, role=2, site=site.id, status="planned",
    custom_fields={"ticket": "INC42"},
)
lot = nb.dcim.sites.create([
    {"name": "A", "slug": "a"},
    {"name": "B", "slug": "b"},
])                                      # liste en entrée -> liste de Record
```

## Modifier

```python
dev = nb.dcim.devices.get(name="sw1")
dev.serial = "ABC123"
dev.custom_fields["ticket"] = "INC43"   # modification en place suivie
dev.save()                              # PATCH des seuls champs changés ; True si envoyé

dev.update({"status": "active", "role": 5})   # affecte puis save()

nb.dcim.devices.update([                # en masse
    {"id": 10, "status": "active"},
    {"id": 11, "status": "offline"},
])
```

- `save()` renvoie False s'il n'y a rien à envoyer.
- `dev.updates()` montre le dict qui serait envoyé.
- Pour un objet lié, affecte un id (`dev.site = 6`).

## Supprimer

```python
dev.delete()                               # True si succès
nb.dcim.devices.delete([10, 11])           # ids ou Record ; en masse
nb.dcim.devices.filter(site="old").delete()
```

## Endpoints de détail

```python
pfx = nb.ipam.prefixes.get(prefix="10.0.0.0/24")
pfx.available_ips.list()
ip = pfx.available_ips.create()                       # prochaine IP libre
ips = pfx.available_ips.create([{} for _ in range(3)])
sub = pfx.available_prefixes.create({"prefix_length": 28})
nb.ipam.vlan_groups.get(1).available_vlans.create({"name": "v100"})
nb.dcim.interfaces.get(7).trace()
nb.dcim.devices.get(1).render_config.create()
```

## Choix possibles

```python
nb.dcim.devices.choices()   # {"status": [{"value": ..., "display_name": ...}], ...}
```

Nécessite un jeton ayant le droit d'écrire sur l'endpoint (requête OPTIONS).

## Erreurs

```python
import pynetbox
try:
    nb.dcim.devices.create(name="sw1")
except pynetbox.RequestError as e:
    print(e.error)          # texte brut de la réponse (souvent du JSON : champ -> erreur)
    print(e.req.status_code)
```

Autres exceptions : `pynetbox.ContentError` (réponse non JSON), `pynetbox.AllocationError` (plus de place libre dans `available_*`).

## Pièges

- N'utilise pas `device_role` : en 4.0 c'est `role` (attribut et filtre).
- `get()` avec des kwargs fait un `filter()` : si le filtre est ignoré, tu obtiens `ValueError` (plusieurs résultats).
- `threading=True` accélère les grandes listes mais multiplie les requêtes simultanées.
- Ne mets ni URL ni jeton en dur : variables d'environnement.
