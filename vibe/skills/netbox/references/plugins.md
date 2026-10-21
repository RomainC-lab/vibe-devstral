# Plugins NetBox 4.0.11

Sources : `docs/plugins/development/*.md` (dont `migration-v4.md`) et `netbox/netbox/plugins/` au tag v4.0.11.

## Structure

```
mon-projet/
  pyproject.toml
  README.md
  mon_plugin/
    __init__.py          # PluginConfig + variable config
    models.py
    filtersets.py
    forms.py
    tables.py
    views.py
    urls.py
    navigation.py        # menu_items
    template_content.py  # template_extensions
    graphql.py           # schema
    search.py            # indexes
    api/
      __init__.py
      serializers.py
      views.py
      urls.py
    migrations/
      __init__.py
    templates/mon_plugin/*.html
```

- Mets un `__init__.py` dans chaque dossier Python (`mon_plugin/`, `api/`, `migrations/`). NetBox détecte `urls` et `api.urls` comme sous-modules du paquet.
- Le nom du dossier source = nom Python du plugin (minuscules, chiffres, `_`).
- `requires-python = ">=3.10"` dans `pyproject.toml`.

## PluginConfig

```python
# mon_plugin/__init__.py
from netbox.plugins import PluginConfig


class MonPluginConfig(PluginConfig):
    name = "mon_plugin"
    verbose_name = "Mon plugin"
    description = "Exemple"
    version = "0.1.0"
    base_url = "mon-plugin"
    min_version = "4.0.0"
    max_version = "4.0.99"
    default_settings = {"actif": True}
    required_settings = []


config = MonPluginConfig
```

- Import depuis `netbox.plugins` (l'ancien `extras.plugins` n'existe plus en 4.0).
- NetBox lit la variable `config` du `__init__.py`.
- `min_version` / `max_version` sont comparés comme versions complètes : `max_version = "4.0"` **refuse** 4.0.11 (4.0.11 > 4.0). Écris `"4.0.99"`.
- Version hors bornes : `ImproperlyConfigured`, NetBox ne démarre pas.
- Autres attributs : `author`, `author_email`, `django_apps`, `middleware`, `queues`, `search_extensions`, `data_backends`, `template_extensions`, `menu_items`, `graphql_schema`, `user_preferences`.
- Lire un paramètre : `from netbox.plugins import get_plugin_config` puis `get_plugin_config("mon_plugin", "actif")`.

Activation dans `configuration.py` :

```python
PLUGINS = ["mon_plugin"]
PLUGINS_CONFIG = {"mon_plugin": {"actif": False}}
```

Installation en développement : `pip install -e .` dans le venv de NetBox.

## Modèles et migrations

```python
from django.db import models
from netbox.models import NetBoxModel


class Equipement(NetBoxModel):
    nom = models.CharField(max_length=100)
    site = models.ForeignKey(to="dcim.Site", on_delete=models.CASCADE, related_name="+")

    class Meta:
        ordering = ("nom",)

    def __str__(self):
        return self.nom
```

- `NetBoxModel` ajoute tags, custom fields, changelog, journal, export, etc.
- Pour quelques fonctions seulement : mixins de `netbox.models.features` (ex. `TagsMixin`, `ExportTemplatesMixin`) + `models.Model`.
- Choix : sous-classe de `utilities.choices.ChoiceSet` avec un tuple `CHOICES`.
- Migrations : mets `DEVELOPER = True` dans `configuration.py`, puis `./manage.py makemigrations mon_plugin` et `./manage.py migrate mon_plugin`.
- Pour référencer des types d'objets : `core.ObjectType` (ex. `ManyToManyField(to="core.ObjectType")`). Pour une clé générique (GFK), la ForeignKey pointe vers `contenttypes.ContentType`.

## Formulaires (4.0)

```python
from django.utils.translation import gettext_lazy as _
from netbox.forms import NetBoxModelForm
from utilities.forms.rendering import FieldSet


class EquipementForm(NetBoxModelForm):
    fieldsets = (
        FieldSet("nom", "site", "tags", name=_("Équipement")),
    )

    class Meta:
        model = Equipement
        fields = ("nom", "site", "tags")
```

- `fieldsets` : objets `FieldSet(…, name=…)`, plus des tuples `(nom, (champs))`.
- `BootstrapMixin` n'existe plus : retire-le.

## Vues

- Vues génériques : `from netbox.views import generic` (`ObjectView`, `ObjectListView`, `ObjectEditView`, `ObjectDeleteView`, `BulkImportView`, `BulkEditView`, `BulkDeleteView`).
- Onglet sur une vue existante : `utilities.views.ViewTab` et `register_model_view`.
- `actions` d'une vue liste : un **dict** `{"add": {"add"}, "export": set(), "bulk_delete": {"delete"}}`. L'ancien tuple + `action_perms` ne marche plus.
- URL : namespace `plugins:<nom_plugin>:<nom_url>` ; chemin `/plugins/<base_url>/…`.

## Contenu injecté dans les pages

```python
# template_content.py
from netbox.plugins import PluginTemplateExtension


class SiteEquipements(PluginTemplateExtension):
    model = "dcim.site"            # un seul modèle en 4.0 ; `models` arrive en 4.1

    def right_page(self):
        return self.render("mon_plugin/inc/equipements.html", extra_context={"n": 3})


template_extensions = [SiteEquipements]
```

Méthodes : `left_page()`, `right_page()`, `full_width_page()`, `buttons()`, `list_buttons()`. Contexte : `self.context` (`object`, `request`, `settings`, `config`).

## Menu

```python
# navigation.py
from netbox.plugins import PluginMenuButton, PluginMenuItem

menu_items = (
    PluginMenuItem(
        link="plugins:mon_plugin:equipement_list",
        link_text="Équipements",
        buttons=(PluginMenuButton("plugins:mon_plugin:equipement_add", "Ajouter", "mdi mdi-plus-thick"),),
    ),
)
```

En 4.0, les boutons de menu ne sont plus colorés : n'indique pas de couleur.

## API REST

```python
# api/serializers.py
from rest_framework import serializers
from netbox.api.serializers import NetBoxModelSerializer
from dcim.api.serializers import SiteSerializer
from ..models import Equipement


class EquipementSerializer(NetBoxModelSerializer):
    url = serializers.HyperlinkedIdentityField(view_name="plugins-api:mon_plugin-api:equipement-detail")
    site = SiteSerializer(nested=True)

    class Meta:
        model = Equipement
        fields = ("id", "url", "display", "nom", "site", "tags", "custom_fields", "created", "last_updated")
        brief_fields = ("id", "url", "display", "nom")
```

```python
# api/views.py
from netbox.api.viewsets import NetBoxModelViewSet
from ..models import Equipement
from .serializers import EquipementSerializer


class EquipementViewSet(NetBoxModelViewSet):
    queryset = Equipement.objects.all()
    serializer_class = EquipementSerializer
```

```python
# api/urls.py
from netbox.api.routers import NetBoxRouter
from .views import EquipementViewSet

router = NetBoxRouter()
router.register("equipements", EquipementViewSet)
urlpatterns = router.urls          # variable obligatoire
```

- URL obtenue : `/api/plugins/<base_url>/equipements/`.
- 4.0 : un seul serializer pour les modes normal et brief. Déclare `brief_fields` dans `Meta` ; pour un objet lié, utilise le serializer principal avec `nested=True`.
- Les classes `Nested…Serializer` / `WritableNestedSerializer` existent encore en 4.0 (dépréciées en 4.1, supprimées en 4.2). Pour du code neuf, préfère `nested=True`.
- `?fields=` et `?brief=` marchent aussi sur les endpoints du plugin grâce à `NetBoxModelViewSet`.
- Ajoute un filterset (`filterset_class`) sur le viewset pour permettre le filtrage.

## GraphQL (Strawberry)

```python
# graphql.py
from typing import List
import strawberry
import strawberry_django
from netbox.graphql.types import NetBoxObjectType
from . import models


@strawberry_django.type(models.Equipement, fields="__all__")
class EquipementType(NetBoxObjectType):
    pass


@strawberry.type
class Query:
    @strawberry.field
    def equipement(self, id: int) -> EquipementType:
        return models.Equipement.objects.get(pk=id)

    equipement_list: List[EquipementType] = strawberry_django.field()


schema = [Query]
```

- Plus de `graphene`, `ObjectField`, `ObjectListField` ni `gql_query_optimizer`.
- Filtres : classe décorée par `@strawberry_django.filter(Modele, lookups=True)` et `@autotype_decorator(MonFilterSet)` (de `netbox.graphql.filter_mixins`), héritant de `BaseFilterMixin` ; passe-la via `filters=` dans `@strawberry_django.type`.
- Les clés étrangères et M2M doivent être déclarées comme champs typés sur le type Strawberry si NetBox ne les infère pas.

## Templates (4.0)

- Blocs renommés : `header` → `page-header`, `controls` → `control-buttons` (`generic/object.html`) ; `content-wrapper` supprimé (utilise `content`).
- Bootstrap 5.3 / Tabler : `text-bg-<couleur>` au lieu de `bg-<couleur>` pour les badges ; plus besoin de `btn-sm` ; tableau directement dans `.card` (sans `.card-body`).

## Pièges

- Hors doc plugins, rien n'est une API stable. Un plugin écrit pour 4.1+ (`models = [...]`, `display_url`, jobs 4.1) casse en 4.0.
