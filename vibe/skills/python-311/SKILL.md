---
name: python-311
description: "Écrire du Python qui tourne sur Python 3.11, la version du travail. À utiliser quand tu écris ou modifies du code Python destiné au travail (cible 3.11) : scripts, modules, tests, typage, choix de syntaxe ou de module standard."
user-invocable: true
allowed-tools:
  - read_file
  - grep
  - bash
  - ask_user_question
---

# Python 3.11

**Cible : Python 3.11.** Le code que tu écris doit tourner sur 3.11, rien de plus récent.

Attention : Vibe tourne lui-même sur Python 3.12 (ou plus). Le `python` de ta session n'est donc **pas** la cible. Un code qui passe sur 3.12 peut planter en 3.11 : un test local en 3.12 ne prouve rien pour 3.11.

## Règles

1. Suis la version 3.11. En cas de doute sur la disponibilité d'une fonction, d'un module ou d'une syntaxe en 3.11 : ne l'utilise pas, dis-le, et demande avec `ask_user_question` (ou prends une solution plus ancienne et sûre).
2. N'utilise rien de la liste « Interdit » ci-dessous. Pour chaque cas, le remplacement 3.11 est dans `references/interdit-3.12-et-plus.md`.
3. Évite aussi les modules dépréciés, même s'ils existent encore en 3.11 (voir « Modules à éviter »).
4. Vérifie avant de dire « ça marche » (voir « Vérifier »). Si aucun Python 3.11 n'est disponible, écris clairement : « non testé sur 3.11, testé seulement sur 3.12 ».

## Disponible en 3.11 (tu peux l'utiliser)

- `match` / `case` (3.10) et les unions `int | None` dans les annotations et `isinstance` (3.10).
- `zip(..., strict=True)` (3.10).
- `tomllib` pour lire du TOML (lecture seule).
- `ExceptionGroup` et `except*` ; `exc.add_note("...")`.
- `asyncio.TaskGroup`, `asyncio.timeout(...)`, `asyncio.Runner`.
- `typing` : `Self`, `LiteralString`, `Never`, `Required` / `NotRequired`, `TypeVarTuple` / `Unpack`, `assert_never`, `assert_type`, `reveal_type`, `dataclass_transform`. Déjà là avant : `TypeAlias`, `ParamSpec`, `TypeGuard`.
- `enum.StrEnum`, `datetime.UTC`, `contextlib.chdir`, `hashlib.file_digest`, `operator.call`.
- `datetime.fromisoformat()` accepte la plupart des formats ISO 8601.
- Messages d'erreur plus précis (le traceback pointe l'expression fautive).

Exemples courts : `references/nouveautes-3.11.md`.

## Interdit (3.12 et plus)

Syntaxe (erreur de syntaxe en 3.11, le fichier entier refuse de se charger) :
- `type Point = tuple[float, float]` (3.12).
- Génériques en crochets : `def f[T](x: T)`, `class Boite[T]:` (3.12), et leurs valeurs par défaut `[T = int]` (3.13).
- f-strings « libres » (3.12) : mêmes guillemets dedans (`f"{d["a"]}"`), antislash dans les accolades (`f"{'\n'.join(xs)}"`), commentaire `#` dans les accolades.
- t-strings `t"Bonjour {nom}"` (3.14).
- `except A, B:` sans parenthèses (3.14) : écris `except (A, B):`.

Annotations (3.14) : en 3.11, les annotations sont évaluées tout de suite. `def f(x: Classe)` avant la définition de `Classe` lève `NameError`. Mets des guillemets (`"Classe"`) ou `from __future__ import annotations` en tête du fichier.

Bibliothèque standard :
- 3.12 : `itertools.batched`, `typing.override`, `pathlib.Path.walk`, `Path.with_segments`, `calendar.Month` / `calendar.Day` (et `calendar.JANUARY`…), `sys.monitoring`, `os.path.splitroot`, `shutil.rmtree(onexc=...)`.
- 3.13 : `copy.replace`, `warnings.deprecated`, `typing.ReadOnly`, `typing.TypeIs`, `PythonFinalizationError`, `os.process_cpu_count`, `Path.from_uri`, `base64.z85encode`.
- 3.14 : `annotationlib`, `string.templatelib`, `concurrent.interpreters`, `compression.zstd`.

Attention aux noms proches : `Path.is_relative_to` (3.9) et `datetime.UTC` (3.11) sont **autorisés**.

## Modules à éviter

Ces modules existent encore en 3.11 mais sont dépréciés et ont disparu ensuite. N'en mets pas dans du code neuf, pour qu'il survive à une mise à jour de Python :
- supprimés en 3.12 : `distutils`, `imp`, `asynchat`, `asyncore`, `smtpd` ;
- supprimés en 3.13 : `aifc`, `audioop`, `cgi`, `cgitb`, `chunk`, `crypt`, `imghdr`, `mailcap`, `msilib`, `nis`, `nntplib`, `ossaudiodev`, `pipes`, `sndhdr`, `spwd`, `sunau`, `telnetlib`, `uu`, `xdrlib`, `lib2to3`.

Si du code existant les utilise, ne le réécris pas sans qu'on te le demande : signale-le.

## Pièges

- `datetime.utcnow()` et `datetime.utcfromtimestamp()` marchent en 3.11 mais sont dépréciés depuis 3.12. Écris `datetime.now(UTC)` et `datetime.fromtimestamp(ts, tz=UTC)` (avec `from datetime import datetime, UTC`).
- `tomllib` lit seulement ; il n'écrit pas de TOML.
- `typing_extensions` (paquet externe) fournit `override`, `TypeIs`, `ReadOnly`… pour 3.11. Utilise-le seulement s'il est déjà une dépendance du projet (cherche-le avec `grep` dans `pyproject.toml` / `requirements*.txt`). N'ajoute pas de dépendance sans demander.
- Pas d'accès internet au travail : ne propose pas un `pip install` comme étape obligatoire.

## Vérifier

1. Si Python 3.11 est installé (Windows : `py -3.11 --version`) : `py -3.11 -m py_compile fichier.py`, puis les tests avec `py -3.11 -m pytest -q`.
2. Sinon, au minimum avec le Python de Vibe : `python -c "import ast, sys; ast.parse(open(sys.argv[1], encoding='utf-8').read(), feature_version=(3, 11))" fichier.py`. Ce contrôle est partiel : il ne voit **pas** les f-strings 3.12 ni les fonctions de bibliothèque manquantes. Relis donc le code avec la liste « Interdit ».
3. Si `vermin` ou `ruff` sont déjà installés, utilise-les (détails dans `references/verifier-compatibilite.md`).
4. Dans ta réponse, dis sur quelle version le code a vraiment été testé.

## Fichiers de référence

- `references/interdit-3.12-et-plus.md` : chaque élément interdit et son remplacement 3.11.
- `references/nouveautes-3.11.md` : ce que 3.11 apporte, avec mini-exemples.
- `references/verifier-compatibilite.md` : comment vérifier la compatibilité 3.11, et les limites de chaque outil.
