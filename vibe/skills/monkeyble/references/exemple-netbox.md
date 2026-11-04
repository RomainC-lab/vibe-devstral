# Monkeyble 1.7.1 : exemple complet, rôle qui appelle netbox.netbox

Cet exemple a été lancé tel quel avec ansible-core 2.17.14, Python 3.11.18, hpe.monkeyble 1.7.1 et netbox.netbox 3.21.0, **sans** NetBox et sans pynetbox : les 2 scénarios passent. Noms, adresses et jeton sont factices. Adapte les noms de rôle, de tâches et de variables à ceux du vrai projet (lis-les dans le code, ne les devine pas).

## Arborescence
```text
projet/
├── monkeyble.cfg                 # config Ansible des tests (callback)
├── monkeyble.yml                 # suite de tests pour la CLI
├── playbook.yml
├── roles/pop_netbox/
│   ├── defaults/main.yml
│   └── tasks/main.yml
└── tests/monkeyble/
    ├── scenarios.yml             # variables factices + scénarios + mocks
    └── cas-actif.yml             # une valeur d'entrée différente
```

## monkeyble.cfg
```ini
[defaults]
collections_path = ./collections
roles_path = ./roles
callbacks_enabled = hpe.monkeyble.monkeyble_callback
jinja2_native = True
```

## Le rôle testé
```yaml
# roles/pop_netbox/defaults/main.yml
pop_site: "pop-exemple"
pop_status: "planned"
```
```yaml
# roles/pop_netbox/tasks/main.yml
- name: Créer le site du POP dans NetBox
  netbox.netbox.netbox_site:
    netbox_url: "{{ netbox_url }}"
    netbox_token: "{{ netbox_token }}"
    data:
      name: "{{ pop_site }}"
      slug: "{{ pop_site | lower }}"
      status: "{{ pop_status }}"
    state: present
  register: site_cree

- name: Garder l'id du site
  ansible.builtin.set_fact:
    pop_site_id: "{{ site_cree.site.id }}"

- name: Créer l'équipement du POP
  netbox.netbox.netbox_device:
    netbox_url: "{{ netbox_url }}"
    netbox_token: "{{ netbox_token }}"
    data:
      name: "{{ pop_site }}-sw1"
      site: "{{ pop_site_id }}"
      device_type: "switch-exemple"
      role: "acces"
    state: present
  register: equipement

- name: Arrêter si le site n'est pas actif
  ansible.builtin.fail:
    msg: "Site {{ pop_site }} pas actif"
  when: pop_status != "active"
```
```yaml
# playbook.yml
- name: Pop NetBox
  hosts: localhost
  connection: local
  gather_facts: false
  roles:
    - pop_netbox
```

## Les scénarios
```yaml
# tests/monkeyble/scenarios.yml
netbox_url: "https://netbox.exemple"     # factice : un mock oublié échoue sans rien toucher
netbox_token: "FAUX-JETON"

mock_site:
  config:
    hpe.monkeyble.monkeyble_module:
      consider_changed: true
      result_dict:
        site:
          id: 42
          name: "pop-exemple"

monkeyble_scenarios:
  site_planifie:
    name: "Site planned : le rôle crée site et équipement puis s'arrête"
    tasks_to_test:
      - task: "Créer le site du POP dans NetBox"
        role: pop_netbox
        test_input:
          - assert_dict_equal:
              arg_name: data
              expected:
                name: "pop-exemple"
                slug: "pop-exemple"
                status: "planned"
        mock: "{{ mock_site }}"
        should_be_changed: true
      - task: "Garder l'id du site"
        test_output:
          - assert_equal:
              result_key: result.ansible_facts.pop_site_id
              expected: 42                  # un nombre grâce à jinja2_native
      - task: "Créer l'équipement du POP"
        test_input:
          - assert_equal:
              arg_name: data
              expected:
                name: "pop-exemple-sw1"
                site: 42
                device_type: "switch-exemple"
                role: "acces"
        mock:
          config:
            hpe.monkeyble.monkeyble_module:
              consider_changed: true
              result_dict:
                device:
                  id: 7
        test_output:
          - assert_equal:
              result_key: result.device.id
              expected: 7
      - task: "Arrêter si le site n'est pas actif"
        should_fail: true

  site_actif:
    name: "Site actif : pas d'arrêt"
    tasks_to_test:
      - task: "Créer le site du POP dans NetBox"
        mock: "{{ mock_site }}"
      - task: "Créer l'équipement du POP"
        mock: "{{ mock_site }}"
      - task: "Arrêter si le site n'est pas actif"
        should_be_skipped: true
```
```yaml
# tests/monkeyble/cas-actif.yml
pop_status: "active"
```

## La suite pour la CLI
```yaml
# monkeyble.yml
monkeyble_test_suite:
  - playbook: playbook.yml
    extra_vars:
      - roles/pop_netbox/defaults/main.yml   # OBLIGATOIRE : test_input lit pop_site (bug #63)
      - tests/monkeyble/scenarios.yml
    scenarios:
      - site_planifie
  - playbook: playbook.yml
    extra_vars:
      - tests/monkeyble/scenarios.yml
      - tests/monkeyble/cas-actif.yml        # pop_status: active, partout (y compris le when:)
    scenarios:
      - site_actif
```
Le 2e test n'a pas de `test_input`, il n'a donc pas besoin des `defaults/` (les mocks seuls marchent avec les defaults du rôle).

## Lancer
```bash
ANSIBLE_CONFIG=monkeyble.cfg monkeyble test
```
Sortie attendue (raccourcie) :
```text
TASK [pop_netbox : Créer le site du POP dans NetBox] ****
🙈 Monkeyble test input passed ✔
🙉 Monkeyble mock module - Before: 'netbox.netbox.netbox_site' Now: 'hpe.monkeyble.monkeyble_module'
changed: [localhost]
🐵 Monkeyble - Task 'Créer le site du POP dans NetBox' - expected 'should_be_changed': True. actual state: True
TASK [pop_netbox : Garder l'id du site] ****
🙊 Monkeyble test output passed ✔
...
fatal: [localhost]: FAILED! => {"changed": false, "msg": "Site pop-exemple pas actif"}
🐵 Monkeyble - Task 'Arrêter si le site n'est pas actif' failed as expected

 Playbook     | Scenario      | Test passed
--------------+---------------+---------------
 playbook.yml | site_planifie | ✅
 playbook.yml | site_actif    | ✅
🐵 Monkeyble test result - Tests passed: 2 of 2 tests
```

## Ce que l'essai a montré
- Sans `roles/pop_netbox/defaults/main.yml` en extra var, `site_planifie` affiche `[WARNING]: Failure using method (v2_runner_on_start) … 'pop_site' is undefined`, le mock n'est **pas** appliqué et le vrai `netbox.netbox.netbox_site` tourne (ici il a échoué faute de pynetbox). D'où les fausses adresses et l'absence de pynetbox dans l'environnement de test : un oubli ne peut rien casser.
- Sans `jinja2_native = True`, `pop_site_id` vaut `"42"` (chaîne) et le `test_output` échoue.
- Avec `-e pop_site=autre`, le `test_input` échoue : `❌ MONKEYBLE ERROR ❌`, le JSON montre `tested_value` (valeur réelle) et `expected`, code 1, le playbook s'arrête.

## Idées de scénarios pour un rôle NetBox
- Les arguments envoyés à chaque module `netbox.netbox.*` (nom, slug, statut, rattachements) pour un jeu d'entrées type survey AAP.
- Une entrée invalide → la tâche `ansible.builtin.assert` / `fail` de contrôle doit échouer (`should_fail: true`) **avant** tout appel NetBox (`should_be_skipped` impossible après l'arrêt : mets le `should_fail` sur la tâche de contrôle).
- Un objet déjà présent → mock avec `consider_changed: false`, la suite doit sauter la création (`should_be_skipped: true`).
- NetBox en erreur → mock avec `failed: true` + `msg`, le `rescue` doit tourner (`should_be_skipped: false`).
- Une valeur lue par `nb_lookup` → `when: <var> is not defined` dans le rôle et valeur donnée en `-e` (voir `mock.md`).
