# Execution environments (AAP 2.4)

## Le principe

- Un execution environment (EE) est une image de conteneur dans laquelle le controller lance `ansible-playbook`.
- Il contient : ansible-core, ansible-runner, Python, les collections, leurs libs Python et les paquets système.
- Plus de virtualenv sur le serveur comme avec Tower : tout ce dont le playbook a besoin doit être DANS l'image (ou, pour les collections, dans `collections/requirements.yml` du projet).
- On construit un EE avec `ansible-builder` (version 3 en AAP 2.4) et `podman` (ou docker).

## Images Red Hat pour AAP 2.4

Sur `registry.redhat.io` (compte Red Hat ou token de service requis) :

| Image | Contenu |
|---|---|
| `ansible-automation-platform-24/ee-minimal-rhel8` / `-rhel9` | ansible-core + ansible-runner, sans collection |
| `ansible-automation-platform-24/ee-supported-rhel8` / `-rhel9` | minimal + les collections supportées par Red Hat et leurs dépendances |

Version d'ansible-core :
- La doc AAP 2.4 indique ansible-core 2.15 dans ee-minimal.
- Le correctif AAP 2.4 du 25 février 2026 a passé ee-minimal et ee-supported à Python 3.12 et ansible-core 2.16 (image en version 2.0.0) et a retiré `frr.frr` et `openvswitch.openvswitch` d'ee-supported.
- Donc ça dépend du tag utilisé. Vérifie toujours dans l'image réelle :

```bash
podman run --rm <image> ansible --version
podman run --rm <image> ansible-galaxy collection list
podman run --rm <image> pip list
```

Au travail, les images viennent souvent d'un hub privé ou d'un miroir interne : demande l'adresse, ne suppose pas `registry.redhat.io`.

## Choix de l'EE pour un job

Le controller prend le premier défini parmi :
1. l'EE du job template (ou celui donné au lancement si « Prompt on launch ») ;
2. l'EE par défaut du projet ;
3. l'EE par défaut de l'organisation ;
4. l'EE par défaut global.

Réglages d'un EE dans le controller : nom, image complète avec tag, politique de pull (« Always », « Only pull if not present » par défaut, « Never »), organisation (vide = partagé), credential de registry si l'image est protégée.

Avec « Only pull if not present » et un tag fixe comme `latest`, une nouvelle image poussée sous le même tag n'est PAS reprise sur les nœuds qui l'ont déjà : change de tag (ex. `1.3.0`) ou passe en « Always ».

## `execution-environment.yml` (schéma version 3)

Fichier lu par défaut : `execution-environment.yml` du répertoire courant (sinon `-f`). Sept sections possibles : `version`, `images`, `dependencies`, `additional_build_files`, `additional_build_steps`, `build_arg_defaults`, `options`.

Exemple : partir d'ee-minimal et ajouter une collection, des libs Python et un paquet système.

```yaml
---
version: 3

images:
  base_image:
    name: registry.redhat.io/ansible-automation-platform-24/ee-minimal-rhel9:latest

dependencies:
  galaxy: requirements.yml
  python: requirements.txt
  system: bindep.txt

options:
  package_manager_path: /usr/bin/microdnf   # les images Red Hat utilisent microdnf
```

`requirements.yml` :

```yaml
---
collections:
  - name: netbox.netbox
    version: ">=3.19.0"
  - name: ansible.utils
```

`requirements.txt` :

```
pynetbox
netaddr
```

`bindep.txt` (format bindep, `[platform:rpm]` pour RHEL) :

```
git [platform:rpm]
```

Les dépendances peuvent aussi être écrites directement :

```yaml
dependencies:
  galaxy:
    collections:
      - name: community.general
  python:
    - jmespath
  system:
    - openssh-clients [platform:rpm]
```

Autres clés de `dependencies` :
- `ansible_core: {package_pip: ansible-core==2.15.x}` et `ansible_runner: {package_pip: ansible-runner}` : seulement si l'image de base ne les a pas déjà (les images ee-* Red Hat les ont).
- `python_interpreter: {package_system: ..., python_path: ...}` : choisir le Python.

Les libs Python déclarées par les collections (leur `requirements.txt` / `meta/execution-environment.yml`) sont ajoutées automatiquement. Ajoute à la main celles que la collection ne déclare pas.

### Étapes de build supplémentaires

`additional_build_steps` accepte `prepend_base`, `append_base`, `prepend_galaxy`, `append_galaxy`, `prepend_builder`, `append_builder`, `prepend_final`, `append_final` (liste ou texte multiligne de directives Containerfile).

Ajouter le certificat d'une autorité interne :

```yaml
additional_build_files:
  - src: files/ca-interne.crt
    dest: configs

additional_build_steps:
  prepend_base:
    - COPY _build/configs/ca-interne.crt /usr/share/pki/ca-trust-source/anchors/
    - RUN update-ca-trust
```

Utiliser un hub privé pour les collections sans laisser le token dans l'image :

```yaml
additional_build_steps:
  prepend_galaxy:
    - ARG ANSIBLE_GALAXY_SERVER_HUB_TOKEN
    - ENV ANSIBLE_GALAXY_SERVER_LIST=hub
    - ENV ANSIBLE_GALAXY_SERVER_HUB_URL=<url-du-hub>
```

puis `ansible-builder build --build-arg ANSIBLE_GALAXY_SERVER_HUB_TOKEN ...` (valeur prise dans l'environnement). L'URL exacte du hub se demande à l'utilisateur.

`build_arg_defaults` fixe des arguments de build : `ANSIBLE_GALAXY_CLI_COLLECTION_OPTS` (ex. `--pre`), `ANSIBLE_GALAXY_CLI_ROLE_OPTS`, `PKGMGR_PRESERVE_CACHE`. Un `--build-arg` en ligne de commande gagne.

## Construire et publier

```bash
ansible-builder build -t ee-reseau:1.0.0 -f execution-environment.yml -v 3
podman run --rm ee-reseau:1.0.0 ansible-doc -l netbox.netbox
podman run --rm ee-reseau:1.0.0 python3 -c "import pynetbox"
podman tag ee-reseau:1.0.0 hub.exemple/equipe/ee-reseau:1.0.0
podman push hub.exemple/equipe/ee-reseau:1.0.0
```

- Sans `-t`, l'image s'appelle `ansible-execution-env`.
- `ansible-builder create` produit seulement le contexte (`context/` avec le Containerfile), sans construire.
- Sur RHEL avec l'abonnement AAP, `ansible-builder` s'installe par le dépôt `ansible-automation-platform-2.4-for-rhel-<8|9>-x86_64-rpms`.
- Ensuite, dans le controller : Administration → Execution Environments → Add, avec l'image complète et le credential de registry.

## Diagnostic rapide

- `couldn't resolve module/action` ou `the collection X was not found` : collection absente de l'EE et du `collections/requirements.yml` du projet.
- `ModuleNotFoundError` / `No module named` : lib Python absente de l'EE.
- Commande introuvable (`git`, `ssh`, `rsync`…) : paquet système à ajouter dans `bindep.txt`.
- Erreur de certificat vers un outil interne : CA à ajouter dans l'image (voir plus haut).
- Ça marche en local mais pas dans le controller : compare avec `podman run --rm <image> ...` de la même image et du même tag que dans le controller.
