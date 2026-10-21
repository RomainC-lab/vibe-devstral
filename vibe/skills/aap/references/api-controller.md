# API REST du controller (AAP 2.4, controller 4.5)

Remplace `https://controller.exemple` par l'adresse réelle (demande-la, ne la devine pas).

## Bases

- Racine : `https://controller.exemple/api/`. Version utilisée : `/api/v2/`. Un `GET /api/` donne `current_version`.
- PAS de `/api/controller/v2/` ni de `/api/gateway/` : c'est AAP 2.5.
- Toujours un `/` final : sans lui, réponse 301 (redirection).
- `POST` crée ou déclenche une action, `PATCH`/`PUT` modifie, `DELETE` supprime.
- Le navigateur affiche une API navigable sur les mêmes URL (pratique pour voir les champs).

## Authentification

Ordre de préférence pour un script : token OAuth2 > Basic (login/mot de passe). La session (cookie) sert au navigateur.

Envoyer le token :

```
Authorization: Bearer <token>
```

Créer un token personnel (PAT) en 2.4, avec login/mot de passe une seule fois :

```bash
curl -s -u "$USER_AAP:$PASS_AAP" -X POST \
  -H 'Content-Type: application/json' \
  -d '{"description": "script CI", "application": null, "scope": "write"}' \
  https://controller.exemple/api/v2/users/<user_id>/personal_tokens/
```

- `scope` : `read` ou `write` (`write` pour lancer des jobs).
- Le champ `token` de la réponse n'est visible qu'à la création : garde-le tout de suite.
- Variante : `POST /api/v2/tokens/` (token pour l'utilisateur connecté).
- Ton propre id : `GET /api/v2/me/`.
- Les utilisateurs externes (SSO/LDAP) ne peuvent créer de token que si le réglage « Allow External Users to Create OAuth2 Tokens » est activé.
- Ne mets jamais un token en dur dans un fichier commité : variable d'environnement ou coffre.

## Trouver un objet

Filtres en query string (combinés en ET) :

```
GET /api/v2/job_templates/?name=Deploiement%20web
GET /api/v2/inventories/?name__icontains=prod
GET /api/v2/jobs/?status=failed&order_by=-finished
GET /api/v2/hosts/?search=web01
```

- Suffixes : `exact` (défaut), `iexact`, `contains`, `icontains`, `startswith`, `endswith`, `regex`, `gt`, `gte`, `lt`, `lte`, `isnull`, `in`.
- `not__champ=valeur` exclut ; `or__champ=a&or__champ=b` fait un OU.
- Tri : `order_by=champ`, `-champ` pour l'ordre inverse.
- Named URL (sans id) : `/api/v2/job_templates/<nom>++<organisation>/`, `/api/v2/inventories/<nom>++<organisation>/` (encoder les caractères spéciaux).

## Pagination

Réponse d'une liste :

```json
{"count": 250, "next": "/api/v2/hosts/?page=2", "previous": null, "results": [ ... ]}
```

- Suis `next` jusqu'à `null`.
- `page_size` : 200 maximum par défaut (au-delà, ramené à la limite).

## Lancer un job template

Avant, si besoin : `GET /api/v2/job_templates/<id>/launch/` dit ce qui est demandé au lancement (`ask_variables_on_launch`, `survey_enabled`, `variables_needed_to_start`, `passwords_needed_to_start`…).

```bash
curl -s -X POST \
  -H "Authorization: Bearer $AAP_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"extra_vars": "{\"version\": \"1.4\", \"dry_run\": false}", "limit": "web"}' \
  https://controller.exemple/api/v2/job_templates/42/launch/
```

- La doc 2.4 demande `extra_vars` sous forme de CHAÎNE contenant du JSON (ou du YAML). C'est la forme sûre.
- Les `extra_vars` ne sont prises en compte que si le template a « Prompt on launch » sur Variables ou un survey activé (et seulement les variables du survey dans ce dernier cas). Sinon elles sont ignorées : regarde le champ `ignored_fields` de la réponse.
- Même règle pour `limit`, `inventory`, `credentials`, `job_tags`… : chacun a son `ask_*_on_launch`.
- Codes : 201 lancé ; 400 mot de passe ou variable obligatoire manquant ; 403 droit refusé sur un objet ; 405 lancement impossible.
- Réponse : `id` (et `job`) = id du job créé.

Workflow : `POST /api/v2/workflow_job_templates/<id>/launch/` ; la réponse contient `workflow_job` ; suivi sur `/api/v2/workflow_jobs/<id>/`.

## Suivre un job

```bash
curl -s -H "Authorization: Bearer $AAP_TOKEN" https://controller.exemple/api/v2/jobs/1234/
```

- Champ `status` : `new`, `pending`, `waiting`, `running`, puis final `successful`, `failed`, `error` ou `canceled`.
- `failed` (booléen), `started`, `finished`, `elapsed` aussi utiles.
- Annuler : `POST /api/v2/jobs/<id>/cancel/`.

Sortie du job :

```
GET /api/v2/jobs/<id>/stdout/?format=txt
```

Formats : `txt`, `ansi`, `json`, `html`, `txt_download` (gros fichiers). Synchros : `/api/v2/project_updates/<id>/stdout/`, `/api/v2/inventory_updates/<id>/stdout/`.

## Exemple Python (`requests`)

```python
import json
import os
import time

import requests

BASE = "https://controller.exemple/api/v2"
SESSION = requests.Session()
SESSION.headers["Authorization"] = f"Bearer {os.environ['AAP_TOKEN']}"
VERIFY = os.environ.get("AAP_CA_BUNDLE", True)  # chemin du CA interne si besoin


def get_all(url, params=None):
    """Renvoie tous les résultats d'une liste paginée."""
    results = []
    while url:
        r = SESSION.get(url, params=params, verify=VERIFY)
        r.raise_for_status()
        data = r.json()
        results.extend(data["results"])
        url = data["next"] and requests.compat.urljoin(BASE, data["next"])
        params = None  # déjà inclus dans "next"
    return results


def launch(template_name, extra_vars):
    jts = get_all(f"{BASE}/job_templates/", {"name": template_name})
    if len(jts) != 1:
        raise SystemExit(f"{len(jts)} job templates nommés {template_name!r}")
    r = SESSION.post(
        f"{BASE}/job_templates/{jts[0]['id']}/launch/",
        json={"extra_vars": json.dumps(extra_vars)},
        verify=VERIFY,
    )
    r.raise_for_status()
    data = r.json()
    if data.get("ignored_fields"):
        print("Ignoré par le controller :", data["ignored_fields"])
    return data["id"]


def wait(job_id, timeout=1800):
    end = time.time() + timeout
    while time.time() < end:
        job = SESSION.get(f"{BASE}/jobs/{job_id}/", verify=VERIFY).json()
        if job["status"] in ("successful", "failed", "error", "canceled"):
            return job["status"]
        time.sleep(5)
    raise TimeoutError(job_id)


job_id = launch("Deploiement web", {"version": "1.4"})
status = wait(job_id)
print(status)
print(SESSION.get(f"{BASE}/jobs/{job_id}/stdout/", params={"format": "txt"}, verify=VERIFY).text)
```

- `next` est un chemin qui commence par `/api/v2/…` : `urljoin` le rend absolu.
- Ne mets pas `verify=False` par défaut : demande le certificat de l'autorité interne.
