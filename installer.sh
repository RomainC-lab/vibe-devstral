#!/usr/bin/env bash
# Installe Mistral Vibe (pip) et copie la configuration Devstral dans ~/.vibe/.
# Git Bash :  bash installer.sh            (n'écrase rien)
#             bash installer.sh --force    (remplace, après sauvegarde)
#             bash installer.sh --sans-pip (copie seulement les fichiers)
set -euo pipefail

FORCE=0
SANS_PIP=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --sans-pip) SANS_PIP=1 ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    *) echo "Option inconnue : $arg" >&2; exit 1 ;;
  esac
done

ICI="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$ICI/vibe"

# Dossier de Vibe : $VIBE_HOME, sinon le dossier utilisateur Windows, sinon ~.
if [ -n "${VIBE_HOME:-}" ]; then
  DEST="$VIBE_HOME"
elif [ -n "${USERPROFILE:-}" ] && command -v cygpath >/dev/null 2>&1; then
  DEST="$(cygpath -u "$USERPROFILE")/.vibe"
else
  DEST="$HOME/.vibe"
fi

# 1. Mistral Vibe
if [ "$SANS_PIP" -eq 0 ]; then
  if command -v py >/dev/null 2>&1; then PY=(py -3);
  elif command -v python >/dev/null 2>&1; then PY=(python);
  else PY=(python3); fi
  echo "== Installation de mistral-vibe avec ${PY[*]} -m pip"
  "${PY[@]}" -m pip install --upgrade mistral-vibe || "${PY[@]}" -m pip install --user --upgrade mistral-vibe
  if ! command -v vibe >/dev/null 2>&1; then
    echo "!! La commande « vibe » n'est pas encore dans le PATH."
    echo "   Ajoute ce dossier au PATH Windows puis rouvre le terminal :"
    "${PY[@]}" -c "import sysconfig, os; print('   ' + sysconfig.get_path('scripts')); print('   ' + sysconfig.get_path('scripts', os.name + '_user'))"
  fi
fi

# 2. Fichiers de configuration
echo "== Copie de la configuration vers $DEST"
SAUVEGARDE="$DEST/sauvegarde-$(date +%Y%m%d-%H%M%S)"
gardes=()
cd "$SOURCE"
while IFS= read -r -d '' f; do
  rel="${f#./}"
  cible="$DEST/$rel"
  mkdir -p "$(dirname "$cible")"
  if [ ! -e "$cible" ]; then
    cp "$f" "$cible"; echo "   ajouté      $rel"
  elif cmp -s "$f" "$cible"; then
    echo "   identique   $rel"
  elif [ "$FORCE" -eq 1 ]; then
    mkdir -p "$(dirname "$SAUVEGARDE/$rel")"
    cp "$cible" "$SAUVEGARDE/$rel"
    cp "$f" "$cible"; echo "   remplacé    $rel (ancien dans $SAUVEGARDE)"
  else
    gardes+=("$rel"); echo "   GARDÉ       $rel (le tien est différent)"
  fi
done < <(find . -type f -print0)

# 3. Fichier des clés (seulement s'il n'existe pas)
if [ ! -e "$DEST/.env" ]; then
  cp "$ICI/vibe-env.exemple" "$DEST/.env"
  echo "   créé        .env (à remplir avec ta clé)"
fi

if [ "${#gardes[@]}" -gt 0 ]; then
  echo
  echo "Fichiers gardés tels quels : ${gardes[*]}"
  echo "Pour les remplacer (avec sauvegarde) : bash installer.sh --force"
fi
echo
echo "Fini. Mets ta clé dans $DEST/.env puis lance « vibe » dans un projet."
