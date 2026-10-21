# Scripts personnalisés NetBox 4.0.11

Source : docs `customization/custom-scripts.md` et `netbox/extras/scripts.py` de la v4.0.11.

## Ce qui change en 4.0

- Les rapports (reports) n'existent plus : ils ont été convertis en scripts à la mise à jour. Écris toujours une classe `Script`.
- Les méthodes `test_*` des anciens rapports sont reprises dans `Script` (voir plus bas).
- Chaque script est un objet en base, rattaché à un « module de script » (fichier `.py`).
- `/api/extras/reports/` est supprimé ; tout passe par `/api/extras/scripts/`.
- Depuis 4.0.6 : `log_*()` peut être appelé sans message (incrémente juste le compteur).

## Squelette

```python
from django.utils.text import slugify

from dcim.choices import SiteStatusChoices
from dcim.models import Site
from extras.scripts import Script, StringVar, IntegerVar, ObjectVar, BooleanVar
from tenancy.models import Tenant
from utilities.exceptions import AbortScript


class NouveauSite(Script):
    class Meta:
        name = "Nouveau site"
        description = "Crée un site planifié"
        commit_default = False          # case « Commit » décochée par défaut
        fieldsets = (
            ("Site", ("nom", "locataire")),
            ("Options", ("actif",)),
        )

    nom = StringVar(description="Nom du site", max_length=100)
    locataire = ObjectVar(model=Tenant, required=False)
    actif = BooleanVar(default=False)

    def run(self, data, commit):
        if Site.objects.filter(name=data["nom"]).exists():
            raise AbortScript(f"Le site {data['nom']} existe déjà")
        site = Site(
            name=data["nom"],
            slug=slugify(data["nom"]),
            status=SiteStatusChoices.STATUS_ACTIVE if data["actif"] else SiteStatusChoices.STATUS_PLANNED,
            tenant=data["locataire"],
        )
        site.full_clean()
        site.save()
        self.log_success(f"Site créé : {site}", site)
        return f"id={site.pk}"          # affiché dans l'onglet « Output »
```

- Hérite de `extras.scripts.Script`. `from extras.scripts import *` marche aussi.
- `run(self, data, commit)` : `data` = dict des variables déjà converties (objets du modèle, `netaddr`, dates…) ; `commit` = booléen.
- Si `commit` est faux, NetBox annule toutes les écritures à la fin. Tu n'as pas à gérer la transaction.
- Une exception non attrapée arrête le script, annule les changements en base et affiche la trace ; le job passe en erreur. `AbortScript("message")` arrête proprement, sans trace.
- Appelle `full_clean()` avant `save()` : c'est la validation des formulaires NetBox.

## Attributs `Meta`

- `name` : nom affiché (défaut : nom de la classe).
- `description` : texte court.
- `field_order` : ordre des variables (ignoré si `fieldsets` est défini).
- `fieldsets` : tuple de `(titre, (variables…))` ; une variable absente n'est pas affichée.
- `commit_default` : False pour décocher « Commit » par défaut.
- `scheduling_enabled` : False pour interdire la planification.
- `job_timeout` : durée max en secondes (défaut : `RQ_DEFAULT_TIMEOUT`).

Ordre des scripts dans un module : variable de module `script_order = (ClasseA, ClasseB)`.

## Variables

Options communes : `label`, `description`, `default`, `required` (True par défaut), `widget`.

| Variable | Valeur reçue | Options propres |
|---|---|---|
| `StringVar` | str | `min_length`, `max_length`, `regex` |
| `TextVar` | str (multi-ligne) | — |
| `IntegerVar` | int | `min_value`, `max_value` |
| `BooleanVar` | bool | — |
| `ChoiceVar` | str | `choices` = tuple de `(valeur, libellé)` |
| `MultiChoiceVar` | liste de str | `choices` |
| `ObjectVar` | instance du modèle | `model`, `query_params`, `context`, `null_option` |
| `MultiObjectVar` | queryset/liste d'instances | idem `ObjectVar` |
| `FileVar` | fichier en mémoire | — |
| `IPAddressVar` | `netaddr.IPAddress` (sans masque) | — |
| `IPAddressWithMaskVar` | `netaddr.IPNetwork` | — |
| `IPNetworkVar` | `netaddr.IPNetwork` | `min_prefix_length`, `max_prefix_length` |
| `DateVar` | `datetime.date` | — |
| `DateTimeVar` | `datetime.datetime` | — |

`DecimalVar` n'existe pas en 4.0.11 (ajouté en 4.4).

Filtrer une liste déroulante selon un autre champ (préfixe `$`) :

```python
region = ObjectVar(model=Region, required=False)
site = ObjectVar(model=Site, query_params={"region_id": "$region", "status": "active"})
```

Les clés de `query_params` sont des filtres de l'API REST (slug ou `_id`).

## Journal

- `self.log_debug(message=None, obj=None)`
- `self.log_info(...)`, `self.log_success(...)`, `self.log_warning(...)`, `self.log_failure(...)`
- Ordre : **message puis objet**. Markdown accepté dans le message.
- La valeur renvoyée par `run()` s'affiche dans l'onglet « Output ».

## Méthodes de test (ex-rapports)

```python
from dcim.models import ConsolePort
from extras.scripts import Script

class VerifConsoles(Script):
    class Meta:
        description = "Chaque device actif a une console connectée"

    def test_console(self):
        for port in ConsolePort.objects.filter(device__status="active"):
            if not port.connected_endpoints:
                self.log_failure(f"{port.name} sans connexion", port.device)
            else:
                self.log_success("OK", port.device)
```

- Méthodes nommées `test_*`, sans argument hors `self`.
- Lancées automatiquement si tu **ne redéfinis pas** `run()`. Si tu redéfinis `run()`, appelle `self.run_tests()`.

## Journal des modifications

Avant de modifier un objet existant, prends un instantané pour que le changelog montre l'avant/après :

```python
if obj.pk and hasattr(obj, "snapshot"):
    obj.snapshot()
obj.description = "nouvelle valeur"
obj.full_clean()
obj.save()
```

## Autres outils

- `self.request` : requête HTTP qui a lancé le script (`self.request.user.username`). Vaut `None` si le job a été lancé sans requête : teste-le avant usage.
- `self.load_yaml(nom)` / `self.load_json(nom)` : lisent un fichier sous `SCRIPTS_ROOT` (supprimés en 4.5, présents en 4.0).
- `FileVar` : le fichier n'est pas sauvegardé ; écris-le toi-même si besoin.

## Installer un script

- Ajoute un module de script dans l'UI (menu Personnalisation → Scripts → Ajouter) : soit téléversement du `.py`, soit fichier d'une data source (Git, etc.) avec synchronisation.
- Le fichier est stocké sous `SCRIPTS_ROOT` (défaut `$INSTALL_ROOT/netbox/scripts/`).
- Copier un fichier à la main dans ce dossier ne crée pas l'objet en base : enregistre le module.
- Nom complet d'un script : `<module>.<Classe>` (module = nom du fichier sans `.py`).

## Lancer un script

Permissions : objets `Extras > Script`, `Extras > Script Module`, `Core > Managed File`, plus l'action `run` sur Script.

UI : ouvrir le script, remplir le formulaire, « Run Script ». Planification possible (date, intervalle).

API :

```bash
curl -X POST -H "Authorization: Token $NETBOX_TOKEN" \
  -H "Content-Type: application/json" \
  "$NETBOX_URL/api/extras/scripts/mon_module.NouveauSite/" \
  --data '{"data": {"nom": "Lyon", "actif": true}, "commit": true}'
```

- L'identifiant dans l'URL est l'id numérique du script ou `<module>.<Classe>`.
- `schedule_at` (date-heure) planifie l'exécution.
- La réponse décrit un job ; le résultat est lu ensuite sur le job (`/api/core/jobs/<id>/`).
- Pour un `ObjectVar`, envoie l'id de l'objet.

CLI :

```bash
python3 manage.py runscript --commit --loglevel info --data '{"nom": "Lyon"}' mon_module.NouveauSite
```

Sans `--commit`, les changements sont annulés.

## Pièges

- Pas de `class Report` : la classe de compatibilité `extras.reports.Report` n'existe que pour les migrations et inverse l'ordre des arguments de `log_*`.
- `device_role` n'existe plus sur Device : utilise `role`.
- Pas de `print()` pour informer l'utilisateur : utilise `log_*`.
- Modèles importés depuis leur app : `dcim.models`, `ipam.models`, `tenancy.models`, `virtualization.models`, `extras.models`.
