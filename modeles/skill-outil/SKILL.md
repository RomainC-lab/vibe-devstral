---
name: nom-de-l-outil
description: "Documentation de <OUTIL> <VERSION> utilisé au travail (<à quoi il sert en quelques mots>). À utiliser quand on écrit, modifie ou explique du code, une commande ou une configuration qui touche <OUTIL>, <mot-clé 2>, <mot-clé 3>."
user-invocable: true
allowed-tools:
  - read_file
  - grep
  - bash
  - ask_user_question
---

<!--
MODE D'EMPLOI DU MODÈLE (à effacer une fois rempli)
1. Copie ce dossier dans vibe/skills/<nom-de-l-outil>/ (nom en minuscules, chiffres et tirets seulement,
   64 caractères au plus, le même que la ligne « name: » ci-dessus).
2. Remplis tout ce qui est entre < >. La « description » compte le plus : Vibe ne voit qu'elle tant que la skill
   n'est pas ouverte. Mets-y le nom de l'outil, la version et les mots que tu taperais dans une demande.
   Garde-la entre guillemets doubles "…" (sinon un « : » la casse et Vibe ignore la skill sans prévenir),
   sans guillemet double à l'intérieur ; 1 024 caractères au plus.
3. Garde ce fichier court (moins de ~150 lignes). Les longs détails vont dans references/*.md.
4. N'écris que ce que tu as vérifié dans la doc de TA version. Aucun nom de serveur, adresse, identifiant ni mot de passe.
5. Installe : `bash installer.sh` (ou copie le dossier dans ~/.vibe/skills/), relance vibe, tape /<nom-de-l-outil>.
-->

# <OUTIL> <VERSION>

## Version
- Version cible : **<OUTIL> <VERSION>** (<dépendances utiles : version de Python, de Django, d'ansible-core…>).
- Suis cette version. Si tu ne sais pas si une option, un champ ou une fonction existe dans cette version : dis-le et demande avec `ask_user_question`. N'invente jamais.
- Tu n'as pas internet : cette skill et ses fichiers `references/` sont ta seule documentation de l'outil.

## Ce qui a changé dans cette version
- <changement 1 qui touche le code ou les commandes>
- <changement 2>

## Usage courant
```bash
<commande ou appel le plus fréquent, court>
```
- <règle d'usage 1 (format, option obligatoire, bonne pratique)>
- <règle d'usage 2>

## Pièges
- <erreur qui revient et comment l'éviter>
- <comportement surprenant>

## N'existe PAS dans cette version
Ne les utilise pas, même si tu les connais (ils arrivent plus tard) :
- <fonction ou option de la version suivante>
- <autre>

## Fichiers de référence
Vibe donne le dossier de cette skill quand elle est chargée (« Base directory »). Lis le fichier utile avec `read_file` avant de répondre :
- `references/<sujet-1>.md` : quand <cas où il faut l'ouvrir>.
- `references/<sujet-2>.md` : quand <cas>.
