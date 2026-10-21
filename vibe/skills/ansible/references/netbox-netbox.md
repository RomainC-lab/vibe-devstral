# Collection netbox.netbox (côté Ansible)

Sources : README, CHANGELOG et code de github.com/netbox-community/ansible_modules (tags v3.19.x à v3.23.x), données de build du paquet Ansible 10.
Le serveur NetBox lui-même relève d'un autre skill ; ici : piloter NetBox depuis Ansible.

## Quelle version de la collection ?

| Version | NetBox 4.0 | Ansible annoncé (README) | Python annoncé |
|---|---|---|---|
| < 3.19.0 | non | — | — |
| 3.19.0 / 3.19.1 | oui (premier support NetBox 4.0) | 2.15+ | 3.10+ |
| 3.20.0 | oui | 2.15+ | 3.10+ |
| 3.21.0 | oui | 2.15+ | 3.10+ |
| 3.22.0 et plus | non garanti | **2.18+** | 3.11+ |

- Avec ansible-core 2.17 + NetBox 4.0 : utiliser **3.19.x à 3.21.0**. Le paquet Ansible 10.7.0 embarque **3.20.0**.
- Le README dit que la collection ne vise que « les deux dernières versions de NetBox » au moment de sa sortie : plus la collection est récente, moins NetBox 4.0 est testé.
- Fonctions marquées « NetBox 4.2+ » dans le changelog (ex. `scope` / `scope_type` sur `netbox_prefix`, `primary_mac_address`, module `netbox_mac_address`) : **ne pas utiliser avec NetBox 4.0**.
- Version installée : `ansible-galaxy collection list netbox.netbox`. Fixer la version dans `requirements.yml` :
```yaml
collections:
  - name: netbox.netbox
    version: ">=3.19.0,<3.22.0"
```

## Prérequis Python (sur le contrôleur)

- `pynetbox` : obligatoire pour les **modules** et le lookup `nb_lookup`.
- `pytz` : obligatoire pour l'inventaire `nb_inventory` (il refuse de démarrer sans).
- Installer les deux : `pip install pynetbox pytz` (dans le même environnement Python que ansible-core).
- Jeton API : en écriture pour les modules ; la lecture suffit pour `nb_lookup` et `nb_inventory`.

## Modules

Options communes à tous les modules :
- `netbox_url` (obligatoire) : URL de NetBox, ex. `https://netbox.exemple`.
- `netbox_token` (obligatoire) : jeton API. Pas de lecture automatique d'une variable d'environnement pour les modules : passer la valeur (vault) ou utiliser `module_defaults`.
- `data` (obligatoire) : dictionnaire décrivant l'objet.
- `state` : `present` (défaut) ou `absent` ; `netbox_ip_address` accepte aussi `new` (création forcée).
- `validate_certs` : `true` par défaut. Ne le mettre à `false` que sur un NetBox de test.
- `query_params` : liste des champs qui identifient l'objet de façon unique (si la recherche par défaut est ambiguë).

Les objets liés se désignent par leur nom (ou slug) : `site: Paris`, `device_type: Modele-X`.
Les modules tournent sur le contrôleur : play `hosts: localhost` + `connection: local` + `gather_facts: false`, ou `delegate_to: localhost`.

```yaml
- name: Alimenter NetBox
  hosts: localhost
  connection: local
  gather_facts: false
  module_defaults:
    group/netbox.netbox.netbox:
      netbox_url: "{{ netbox_url }}"
      netbox_token: "{{ vault_netbox_token }}"
  tasks:
    - name: Créer le site
      netbox.netbox.netbox_site:
        data:
          name: Site exemple
          status: active
        state: present

    - name: Créer l'équipement
      netbox.netbox.netbox_device:
        data:
          name: sw-exemple-01
          device_type: Modele-X
          device_role: Commutateur
          site: Site exemple
          status: active
        state: present

    - name: Créer l'interface
      netbox.netbox.netbox_device_interface:
        data:
          device: sw-exemple-01
          name: Ethernet1
          type: 1000base-t
        state: present

    - name: Attribuer une adresse IP à l'interface
      netbox.netbox.netbox_ip_address:
        data:
          address: 192.0.2.10/24
          status: active
          assigned_object:
            device: sw-exemple-01
            name: Ethernet1
        state: present
```
- `module_defaults` avec le groupe `group/netbox.netbox.netbox` évite de répéter URL et jeton.
- Dans `netbox_device`, la clé s'appelle `device_role` (la collection la traduit en `role` pour NetBox 4).
- Récupérer la prochaine IP libre d'un préfixe : `data: { prefix: 192.0.2.0/24 }` avec `state: new`.

Modules courants : `netbox_site`, `netbox_location`, `netbox_rack`, `netbox_manufacturer`, `netbox_device_type`, `netbox_device_role`, `netbox_platform`, `netbox_device`, `netbox_device_interface`, `netbox_ip_address`, `netbox_prefix`, `netbox_vlan`, `netbox_vlan_group`, `netbox_vrf`, `netbox_tenant`, `netbox_tag`, `netbox_cable`, `netbox_cluster`, `netbox_virtual_machine`, `netbox_vm_interface`, `netbox_config_context`, `netbox_custom_field`.
Avant d'utiliser un module : `ansible-doc netbox.netbox.<module>` pour voir ses options exactes dans la version installée.

## Lookup `netbox.netbox.nb_lookup`

Options : premier terme = type d'objet (`devices`, `sites`, `ip-addresses`, `prefixes`…), `api_endpoint`, `token`, `api_filter` (paires `cle=valeur` séparées par des espaces), `validate_certs`, `raw_data`, `plugin`.
Variables d'environnement : `NETBOX_API` (ou `NETBOX_URL`) et `NETBOX_TOKEN` (ou `NETBOX_API_TOKEN`).

```yaml
- name: Lister les équipements d'un site
  ansible.builtin.debug:
    msg: "{{ item.value.name }} (id {{ item.key }})"
  loop: "{{ query('netbox.netbox.nb_lookup', 'devices',
            api_endpoint='https://netbox.exemple',
            api_filter='site=site-exemple status=active',
            token=vault_netbox_token) }}"
```
- Sans `raw_data`, chaque élément est `{key: <id>, value: <objet>}` dans la boucle (d'où `item.key` / `item.value`).
- Avec `raw_data=true`, la liste contient directement les objets.
- Utilise `query(...)` (toujours une liste) plutôt que `lookup(...)` pour boucler.

## Inventaire dynamique `netbox.netbox.nb_inventory`

Nom du fichier : aucun suffixe spécial n'est imposé par le plugin ; il doit seulement finir par `.yml` ou `.yaml` (c'est le plugin `auto` d'ansible-core qui lit la clé `plugin:`). Exemple : `inventaire/netbox.yml`.

```yaml
---
plugin: netbox.netbox.nb_inventory
api_endpoint: https://netbox.exemple
validate_certs: true
config_context: false
group_by:
  - device_roles
  - sites
query_filters:
  - status: active
device_query_filters:
  - has_primary_ip: "true"
```
Avec `plurals: true` (défaut), les variables d'hôte sont des listes à un élément (`sites`, `platforms`…) : vérifie leur forme avec `ansible-inventory --host <hôte>` avant d'écrire un `compose`.
Tester : `ansible-inventory -i inventaire/netbox.yml --graph` puis `--list`.

Options principales :
- `api_endpoint` (obligatoire, ou variable d'environnement `NETBOX_API`).
- `token` (ou `NETBOX_TOKEN`, puis `NETBOX_API_KEY`). Ne pas écrire le jeton dans le fichier : passer par la variable d'environnement.
- `validate_certs` (défaut `true`), `timeout` (défaut 60 s).
- `group_by` : clés de regroupement. Avec `plurals: true` (défaut) on écrit les formes au pluriel (`sites`, `device_roles`, `tags`, `platforms`…) ; avec `plurals: false`, le singulier (`site`, `role`, `tag`, `platform`…).
- `group_names_raw: true` : noms de groupes sans le préfixe de la clé.
- `query_filters` (appareils et VM), `device_query_filters`, `vm_query_filters` : filtres de l'API NetBox. Plusieurs valeurs = OU logique ; suffixe `__n` = négation ; champs personnalisés préfixés par `cf_`.
- `compose`, `keyed_groups`, `groups` : options « constructed » standard pour créer des variables et des groupes.
- `config_context`, `flatten_config_context`, `flatten_custom_fields`, `interfaces`, `services` (défaut `true`), `dns_name`, `ansible_host_dns_name`, `fetch_all`, `virtual_chassis_name`, `oob_ip_as_primary_ip`.
- `hostname_field` et `rename_variables` : à partir de 3.20.0 seulement.
- Cache : options standard `cache`, `cache_plugin`, `cache_timeout`.

`ansible_host` est rempli avec l'IP primaire de l'équipement : filtrer avec `has_primary_ip: "true"` évite les hôtes injoignables (panneaux de brassage, etc.).

## Pièges

- `netbox_url` / `api_endpoint` : l'URL de base de NetBox (sans `/api/`).
- Un nom ambigu (deux interfaces `Ethernet1`) → erreur « More than one result returned » : préciser l'objet parent (`device:`) ou `query_params`.
- Les choix (`status`, `type` d'interface) sont les valeurs de l'API (`active`, `1000base-t`), pas les libellés affichés.
- Mettre `no_log: true` si une tâche affiche le jeton.
- Sans internet : installer la collection et `pynetbox` / `pytz` depuis des paquets déjà téléchargés.
