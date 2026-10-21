# Ce que Python 3.11 apporte (utilisable)

Tout ce qui est ici marche sur 3.11. Les exemples ont été exécutés sur 3.11.

## Lire du TOML : `tomllib`

```python
import tomllib

with open("config.toml", "rb") as f:   # mode binaire obligatoire
    config = tomllib.load(f)
tomllib.loads("a = 1")                  # {'a': 1}
```

Lecture seule : pas de fonction pour écrire.

## Groupes d'exceptions : `ExceptionGroup`, `except*`, `add_note`

```python
try:
    raise ExceptionGroup("plusieurs", [ValueError(1), TypeError(2)])
except* ValueError as eg:
    print("valeurs :", eg.exceptions)
except* TypeError as eg:
    print("types :", eg.exceptions)

e = ValueError("montant invalide")
e.add_note("ligne 12 du fichier client")   # la note s'affiche dans le traceback
```

## asyncio : `TaskGroup` et `timeout`

```python
import asyncio

async def main():
    async with asyncio.timeout(10):
        async with asyncio.TaskGroup() as tg:
            t1 = tg.create_task(lire("a"))
            t2 = tg.create_task(lire("b"))
    return t1.result(), t2.result()
```

Si une tâche échoue, les autres sont annulées et les erreurs remontent dans un `ExceptionGroup`. `asyncio.Runner` existe aussi (pour plusieurs `run` dans la même boucle).

## typing

```python
from typing import Self, NotRequired, TypedDict, assert_never

class Noeud:
    def copier(self) -> Self: ...

class Client(TypedDict):
    nom: str
    email: NotRequired[str]

def traiter(x: int | str) -> None:
    if isinstance(x, int): ...
    elif isinstance(x, str): ...
    else:
        assert_never(x)
```

Aussi en 3.11 : `LiteralString`, `Never`, `Required`, `TypeVarTuple` / `Unpack`, `assert_type`, `reveal_type`, `dataclass_transform`.

## Petites nouveautés utiles

```python
from datetime import datetime, UTC
datetime.now(UTC)                                   # date-heure avec fuseau UTC
datetime.fromisoformat("2026-10-21T08:30:00Z")      # « Z » accepté depuis 3.11

from enum import StrEnum, auto
class Etat(StrEnum):
    OUVERT = auto()       # vaut "ouvert"
Etat.OUVERT == "ouvert"   # True

import hashlib
with open("f.bin", "rb") as f:
    empreinte = hashlib.file_digest(f, "sha256").hexdigest()

from contextlib import chdir
with chdir("sous_dossier"):   # revient au dossier d'origine à la sortie
    ...

import operator
operator.call(len, "abc")     # 3
```

## Rappels 3.10 (aussi disponibles)

```python
match commande:
    case ["copier", source, cible]: ...
    case ["quitter"]: ...
    case _: ...

def f(x: int | None) -> str | None: ...
for a, b in zip(noms, valeurs, strict=True): ...   # ValueError si longueurs différentes
```

## Autres gains

- Tracebacks plus précis : ils soulignent l'expression fautive dans la ligne.
- 3.11 est en moyenne environ 25 % plus rapide que 3.10 (selon la doc officielle, 10 à 60 % suivant le code).
