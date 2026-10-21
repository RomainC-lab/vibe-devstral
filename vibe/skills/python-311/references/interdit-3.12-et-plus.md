# Interdit en 3.11, et quoi écrire à la place

Tout ce qui suit est apparu en 3.12 ou plus. Les remplacements ont été testés sur Python 3.11.

## Syntaxe

| Interdit | Depuis | À écrire en 3.11 |
|---|---|---|
| `type Point = tuple[float, float]` | 3.12 | `Point: TypeAlias = tuple[float, float]` (`from typing import TypeAlias`) |
| `def premier[T](xs: list[T]) -> T` | 3.12 | `T = TypeVar("T")` puis `def premier(xs: list[T]) -> T` |
| `class Boite[T]:` | 3.12 | `class Boite(Generic[T]):` |
| `def f[T = int](...)` (valeur par défaut) | 3.13 | pas d'équivalent : un `TypeVar` sans défaut |
| `f"{d["a"]}"` (mêmes guillemets) | 3.12 | `f"{d['a']}"` |
| `f"{'\n'.join(xs)}"` (antislash) | 3.12 | `sep = "\n"` puis `f"{sep.join(xs)}"` |
| `#` commentaire dans `{ }` d'une f-string | 3.12 | commentaire sur la ligne d'avant |
| `t"Bonjour {nom}"` | 3.14 | f-string, ou `string.Template("Bonjour $nom").substitute(nom=nom)` |
| `except ValueError, TypeError:` | 3.14 | `except (ValueError, TypeError):` |

## Annotations évaluées tout de suite (avant 3.14)

En 3.14, les annotations sont évaluées plus tard. En 3.11, non :

```python
def f(x: Client) -> None: ...   # NameError en 3.11 si Client est défini plus bas
class Client: ...
```

À écrire : `def f(x: "Client")`, ou `from __future__ import annotations` en toute première ligne du fichier.

## Bibliothèque standard

| Interdit | Depuis | À écrire en 3.11 |
|---|---|---|
| `itertools.batched(it, n)` | 3.12 | petit helper (voir plus bas) |
| `@typing.override` | 3.12 | `typing_extensions.override` si le paquet est déjà dans le projet, sinon un commentaire `# redéfinit Parent.m` |
| `Path.walk()` | 3.12 | `os.walk(chemin)` (renvoie des `str`, pas des `Path`) |
| `PurePath.with_segments` | 3.12 | ne pas sous-classer `Path` ; écrire des fonctions qui prennent un `Path` |
| `calendar.Month`, `calendar.Day`, `calendar.JANUARY` | 3.12 | entiers (1 = janvier) et `calendar.month_name[1]` ; `calendar.MONDAY` existe déjà en 3.11 |
| `sys.monitoring` | 3.12 | ne pas utiliser |
| `os.path.splitroot` | 3.12 | `os.path.splitdrive`, puis traiter le reste à la main |
| `shutil.rmtree(p, onexc=f)` | 3.12 | `shutil.rmtree(p, onerror=f)` (signature différente : `f(fonction, chemin, exc_info)`) |
| `copy.replace(obj, x=2)` | 3.13 | `dataclasses.replace(obj, x=2)` pour une dataclass, `nt._replace(x=2)` pour un namedtuple |
| `@warnings.deprecated("...")` | 3.13 | `warnings.warn("...", DeprecationWarning, stacklevel=2)` dans la fonction |
| `typing.TypeIs` | 3.13 | `typing.TypeGuard` (proche, mais ne réduit le type que dans la branche `if`) |
| `typing.ReadOnly` | 3.13 | rien dans `typing` ; `typing_extensions.ReadOnly` si déjà disponible |
| `PythonFinalizationError` | 3.13 | attraper `RuntimeError` (c'en est une sous-classe) |
| `os.process_cpu_count()` | 3.13 | `os.cpu_count()` |
| `Path.from_uri(...)` | 3.13 | ne pas utiliser ; demander si besoin |
| `base64.z85encode` | 3.13 | ne pas utiliser ; demander si besoin |
| `annotationlib`, `string.templatelib` | 3.14 | ne pas utiliser |
| `concurrent.interpreters` | 3.14 | `concurrent.futures.ProcessPoolExecutor` ou `multiprocessing` |
| `compression.zstd` | 3.14 | `zlib`, `gzip`, `bz2` ou `lzma` (même famille d'usage, autre format) |

## Helper `batched` pour 3.11

```python
from itertools import islice

def batched(iterable, n):
    """Découpe en tuples de n éléments (le dernier peut être plus court)."""
    if n < 1:
        raise ValueError("n doit être >= 1")
    it = iter(iterable)
    while lot := tuple(islice(it, n)):
        yield lot

list(batched("ABCDEFG", 3))  # [('A', 'B', 'C'), ('D', 'E', 'F'), ('G',)]
```
