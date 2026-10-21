# Vérifier qu'un code tourne sur Python 3.11

Rappel : Vibe tourne sur 3.12 ou plus. Lancer le code avec le `python` de la session ne prouve rien pour 3.11.

## 1. Le vrai test : un Python 3.11

Sous Windows, le lanceur `py` choisit la version :

```
py -0                              # liste les Python installés
py -3.11 --version
py -3.11 -m py_compile chemin\fichier.py
py -3.11 -m pytest -q
```

`py_compile` attrape les erreurs de syntaxe (f-strings 3.12, `type X = ...`, `def f[T]`). Les fonctions manquantes (`itertools.batched`…) ne se voient qu'à l'exécution : lance aussi les tests.

Si `py -3.11` ne trouve rien : pas de 3.11 sur ce poste. Dis-le dans ta réponse (« non testé sur 3.11 ») et passe aux contrôles partiels ci-dessous.

## 2. Contrôle partiel avec le Python de Vibe : `ast.parse(..., feature_version=(3, 11))`

```
python -c "import ast, sys; ast.parse(open(sys.argv[1], encoding='utf-8').read(), feature_version=(3, 11))" fichier.py
```

La doc le décrit comme un essai « best-effort » : aucune garantie d'avoir le même résultat qu'un vrai 3.11. Testé sur 3.12 :
- **détecte** : `type X = ...`, `def f[T]` / `class C[T]` (et sur 3.14 : t-strings, `except A, B`, défauts de `TypeVar`) ;
- **ne détecte pas** : les f-strings 3.12 (mêmes guillemets, antislash, `#`), les fonctions et modules absents de 3.11, les annotations qui citent une classe définie plus bas.

Donc : utile mais insuffisant. Relis toujours le code avec `interdit-3.12-et-plus.md`.

## 3. Avertissements de dépréciation : `-W error`

```
python -W error -m pytest -q
```

Transforme les avertissements en erreurs : fait sortir par exemple `datetime.utcnow()` (déprécié en 3.12). Ne prouve pas la compatibilité 3.11, mais évite le code qui cassera plus tard.

## 4. Outils optionnels (seulement s'ils sont déjà installés)

Pas d'internet au travail : n'installe rien. Vérifie d'abord avec `vermin --version` ou `ruff --version`.

**vermin** (paquet PyPI) calcule la version minimale de Python requise :

```
vermin -t=3.11- --violations --no-tips fichier_ou_dossier
```

Il signale `itertools.batched`, `typing.override`, les f-strings 3.12, `type X = ...`, et sort avec un code non nul si la cible n'est pas tenue. Lance-le avec le Python de Vibe (3.12) : lancé avec un 3.11, il ne sait pas lire une f-string 3.12, affiche `error:` et peut quand même sortir avec le code 0. Toute ligne `error:` = code non validé.

**ruff** avec la cible 3.11 :

```
ruff check --target-version py311 fichier.py
```

ou dans `pyproject.toml` :

```toml
[tool.ruff]
target-version = "py311"
```

ruff signale la syntaxe trop récente (f-strings 3.12, `type X = ...`) mais **pas** les fonctions de bibliothèque absentes (`itertools.batched`, `typing.override` passent sans erreur).

## 5. Déclarer la cible dans le projet

Dans `pyproject.toml`, si le projet en a un :

```toml
[project]
requires-python = ">=3.11"
```

Cela documente la cible pour les humains et les outils ; ça ne vérifie rien tout seul. Ne modifie pas ce champ sans qu'on te le demande.

## Ce qu'il faut dire à la fin

Une ligne, par exemple :
- « Testé sur Python 3.11 (`py -3.11 -m pytest`) : OK. »
- « Python 3.11 absent du poste : vérifié avec `ast.parse(feature_version=(3, 11))` et relu avec la liste des interdits, non exécuté sur 3.11. »
