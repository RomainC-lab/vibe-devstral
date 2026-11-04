# Monkeyble 1.7.1 : mock (simuler un module)

## En bref
- `mock` remplace le **module** d'une tâche par un autre, juste avant l'exécution. Le vrai module n'est jamais appelé : rien n'est créé dans NetBox, AAP, une machine…
- Le module de remplacement fourni : `hpe.monkeyble.monkeyble_module`. Il renvoie `changed` = `consider_changed`, un `msg` (« Monkeyble Mock module called. Original module: … ») et tout le contenu de `result_dict`.
- Le résultat simulé se `register` comme un vrai : les tâches suivantes peuvent lire `site_cree.site.id`.
- `test_input` est vérifié **avant** le remplacement : arguments réels testés, module simulé.
- Un `mock` par tâche, et une seule clé sous `config:` (la première est prise).

## Syntaxe
```yaml
- task: "Créer le site du POP dans NetBox"
  mock:
    config:
      hpe.monkeyble.monkeyble_module:
        consider_changed: true       # défaut false ; décide de should_be_changed
        result_dict:                 # défaut {} ; fusionné dans le résultat
          site:
            id: 42
            name: "pop-exemple"
```
- Avec une collection installée par Galaxy, écris **`hpe.monkeyble.monkeyble_module`**. Le nom court `monkeyble_module` ne marche qu'avec une installation par clone git et `library = …/plugins/modules` (sinon : « The module monkeyble_module was not found in configured module paths »).
- `result_dict` peut contenir `failed: true` et `msg: "…"` : la tâche échoue comme si NetBox avait répondu une erreur (essayé : le `rescue` s'exécute). Pratique avec `should_fail: true`.
- Pour simuler un module qui ne change rien : `consider_changed: false`.
- Depuis 1.7.0, un `result_dict` qui contient `dest` ou `path` n'est plus écrasé par les infos d'un fichier qui existe vraiment sur le disque.
- Depuis 1.4.4, le mock marche aussi quand le module d'origine a des `module_defaults`.

## Mock réutilisable
```yaml
mock_vide:
  config:
    hpe.monkeyble.monkeyble_module:
      consider_changed: true
      result_dict: {}
monkeyble_scenarios:
  s1:
    name: "…"
    tasks_to_test:
      - task: "Mettre à jour l'interface"
        mock: "{{ mock_vide }}"
```
Pour un mock à mettre dans tous les scénarios : `monkeyble_shared_tasks` (voir `scenarios-et-cli.md`).

## Que mettre dans result_dict ?
- Seulement ce que les tâches **suivantes** lisent (via `register`) et ce que tu testes en `test_output`. Inutile de recopier toute la réponse.
- Modules `netbox.netbox.netbox_*` : la réponse contient l'objet sous une clé à son nom (`site`, `device`, `ip_address`, `prefix`…) et un `msg`. Vérifie le nom de la clé dans la doc du module (`ansible-doc netbox.netbox.netbox_device`, section RETURN) ou dans la skill `ansible` (`references/netbox-netbox.md`) ; si tu n'es pas sûr, demande.
- `ansible.builtin.uri` : mets la réponse sous `json:` (et `status: 200` si une tâche le lit).
- Un module qui renvoie des faits : `ansible_facts: { … }`.

## Ton propre module de mock
```yaml
- task: "task1"
  mock:
    config:
      mon_mock:              # module trouvé dans library/ ou une collection
        mon_arg: "valeur"    # ses arguments
```
- Les arguments d'origine sont remplacés par ceux donnés ici.
- Le module est un module Ansible normal (`AnsibleModule`, `module.exit_json(**result)`), dans un dossier `library/` déclaré dans `monkeyble.cfg`.

## Ce qui ne peut PAS être simulé
- **Lookups et filtres** : `lookup('netbox.netbox.nb_lookup', …)`, `query(…)`, `lookup('ansible.builtin.url', …)`, `lookup('env', …)`… Monkeyble ne remplace que le module, pas un lookup.
  - Essayé (1.7.1, core 2.17) : un `mock` sur un `set_fact` dont l'argument contient `query('netbox.netbox.nb_lookup', …)` **ne marche pas**. Le callback templatise les arguments de toute tâche listée, le lookup est donc lancé ; il plante (WARNING `Failure using method (v2_runner_on_start)`), le mock est sauté et la vraie tâche relance le lookup.
  - Contournement essayé et qui marche : dans le rôle, `when: prefixes is not defined` sur la tâche du lookup ; dans le test, donne `prefixes: [...]` dans le fichier passé en `-e`. La tâche est sautée (le `when:` est évalué avant les arguments) et les tâches suivantes lisent la valeur de test. Ne liste pas cette tâche dans `tasks_to_test` (sinon le WARNING ci-dessus apparaît quand même, sans casser le test).
  - Autre solution côté rôle : remplacer le lookup par une tâche (`ansible.builtin.uri` vers l'API, ou un module `netbox.netbox.*`) avec `register`, puis simuler cette tâche. Propose-le, ne change pas le rôle sans accord.
- **Inventaire dynamique** (`netbox.netbox.nb_inventory`) : il est lu avant le playbook. Pour les tests, donne un petit inventaire statique (`inventory:` dans `monkeyble.yml`).
- **Connexion** : le mock est un module, il est envoyé et exécuté sur l'hôte de la tâche (comme le vrai). Pour une cible distante, il faut donc pouvoir s'y connecter. Les tâches NetBox tournent d'habitude sur `localhost` (`connection: local` ou `delegate_to: localhost`) : pas de souci. En test, préfère un inventaire où les hôtes sont en `ansible_connection: local`.
- `gather_facts` / `setup` sur de vraies machines : mets `gather_facts: false` dans le playbook de test, ou simule la tâche.
- Les handlers ne sont simulés que s'ils sont listés par leur nom comme une tâche.

## Erreurs fréquentes
- Pas de ligne `🙉 Monkeyble mock module - Before: … Now: …` sur la tâche : le mock n'est pas appliqué. Causes : nom de tâche différent (templating, majuscules), filtre `role:`/`play:` qui ne correspond pas, ou un `[WARNING]: Failure using method (v2_runner_on_start)` (souvent une variable de `defaults/` dans un `test_input`). Le **vrai** module tourne alors : en test, garde toujours des adresses et jetons factices pour qu'un oubli échoue sans rien toucher.
- `Failed to import the required Python library (pynetbox)` : même cause (le mock n'est pas appliqué). Bonne nouvelle : sans pynetbox dans l'environnement de test, un mock oublié ne peut pas appeler NetBox.
- `should_be_changed: true` échoue sur une tâche simulée : ajoute `consider_changed: true`.
