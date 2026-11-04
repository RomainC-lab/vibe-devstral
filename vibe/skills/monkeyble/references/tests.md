# Monkeyble 1.7.1 : test_input, test_output et états

## En bref
- `test_input` : vérifie les **arguments du module** juste avant l'exécution, après templating Jinja. Clé : `arg_name`.
- `test_output` : vérifie le **dictionnaire de résultat** de la tâche (celui qu'on obtient avec `register`). Clé : `result_key`.
- États : `should_be_changed`, `should_be_skipped`, `should_fail` (booléens).
- Le premier test raté affiche `❌ MONKEYBLE ERROR ❌` et **arrête le playbook** (code 1).
- Les 10 tests possibles : `assert_equal`, `assert_not_equal`, `assert_in`, `assert_not_in`, `assert_true`, `assert_false`, `assert_is_none`, `assert_is_not_none`, `assert_list_equal`, `assert_dict_equal`. Un autre nom : erreur « Test name '…' is not supported ».

## test_input
```yaml
- task: "Créer le site du POP dans NetBox"
  test_input:
    - assert_dict_equal:
        arg_name: data           # argument de premier niveau du module
        expected:
          name: "pop-exemple"
          slug: "pop-exemple"
          status: "planned"
    - assert_equal:
        arg_name: state
        expected: "present"
```
- `arg_name` = un argument **de premier niveau** du module (`data`, `state`, `netbox_url`…). Pas de chemin `data.name` : pour un sous-champ, compare tout le dictionnaire avec `assert_dict_equal` / `assert_equal`.
- Argument absent de la tâche : erreur « arg_name '…' not present in the list of arguments when executing module '…' ». Un argument laissé à sa valeur par défaut (non écrit dans la tâche) n'est pas visible.
- Les arguments sont templatés avec les variables connues du callback : inventaire, host/group vars, faits et `register`/`set_fact` déjà faits, `vars:` du play, extra vars. **Pas les `defaults/` d'un rôle** (bug ouvert #63, reproduit avec ansible-core 2.17) : passe le fichier `roles/<role>/defaults/main.yml` en extra var, sinon le callback plante et le mock est sauté.
- Les arguments d'une tâche listée sont templatés par le callback : un `lookup()` / `query()` qui s'y trouve est lancé (essayé, même avec un mock). Voir `mock.md`.
- `test_input` est fait **avant** le mock : on peut vérifier les arguments d'un module qui ne sera jamais vraiment appelé.

### Avec une boucle (depuis 1.5.0)
```yaml
# tâche
- name: "Créer les VLAN"
  netbox.netbox.netbox_vlan:
    data:
      name: "{{ item }}"
  loop: ["vlan-10", "vlan-20"]
```
```yaml
- task: "Créer les VLAN"
  test_input:
    - assert_equal:
        arg_name: data
        expected: { name: "vlan-10" }
    - assert_equal:
        arg_name: data
        expected: { name: "vlan-20" }
```
- Chaque test passe si **au moins un** tour de boucle correspond. En cas d'échec, `tested_value` donne la liste des valeurs de tous les tours.
- Le nom de variable de boucle suit `loop_control.loop_var` s'il est donné.

## test_output
```yaml
- task: "Garder l'id du site"
  test_output:
    - assert_equal:
        result_key: result.ansible_facts.pop_site_id
        expected: 42
```
- `result_key` est une expression Jinja **sans** `{{ }}` (comme un `when:`), évaluée avec une seule variable : `result` = le résultat de la tâche. Les variables du playbook n'y sont pas disponibles.
- Après un `set_fact`, la valeur est dans `result.ansible_facts.<nom>`. Après un module NetBox, dans `result.site`, `result.device`… (ou ce que renvoie le mock).
- Clé absente : l'erreur Jinja (« … has no attribute … ») est affichée et le scénario échoue.
- `test_output` ne tourne que si la tâche a réussi (`ok`/`changed`) ; tâche sautée : pas de test de sortie.
- Tous les modules ne renvoient pas de résultat utile : regarde leur doc (`ansible-doc <module>`, section RETURN).
- Avec `jinja2_native = True` les types sont gardés (`42` reste un nombre). Sans, beaucoup de valeurs deviennent des chaînes (`"42"`) et `assert_equal` contre `42` échoue.

## Les 10 assertions
| Test | Réussit si | `expected` |
|---|---|---|
| `assert_equal` | valeur == expected | oui |
| `assert_not_equal` | valeur != expected | oui |
| `assert_in` | expected est **dans** la valeur (élément d'une liste, clé d'un dict, sous-chaîne) | oui |
| `assert_not_in` | expected n'est pas dans la valeur | oui |
| `assert_true` | valeur vraie (`true`, `"true"`, `"True"`, `"1"`, `1`) | non |
| `assert_false` | valeur fausse (`false`, `"false"`, `"False"`, `"0"`, `0`) ; une autre chaîne compte aussi comme fausse | non |
| `assert_is_none` | valeur `null` (en `test_output`, une chaîne vide compte comme `null`) | non |
| `assert_is_not_none` | valeur non `null` | non |
| `assert_list_equal` | listes identiques, **dans le même ordre** | oui |
| `assert_dict_equal` | dictionnaires identiques (ordre des clés sans importance) | oui |

Exemples :
```yaml
test_input:
  - assert_in:
      arg_name: data
      expected: "name"            # la clé name est dans le dict data
  - assert_true:
      arg_name: validate_certs
  - assert_is_none:
      arg_name: query_params
test_output:
  - assert_in:
      result_key: result.ansible_facts.vlans
      expected: "vlan-10"
  - assert_list_equal:
      result_key: result.ansible_facts.vlans
      expected: ["vlan-10", "vlan-20"]
```
- `assert_list_equal` / `assert_dict_equal` exigent le bon type : une chaîne JSON n'est pas un dict.
- Pour tester un `null` en entrée, `jinja2_native = True` est indispensable en 2.17.

## États
```yaml
- task: "Créer le site du POP dans NetBox"
  should_be_changed: true
- task: "Arrêter si le site n'est pas actif"
  should_be_skipped: true
- task: "Vérifier le préfixe"
  should_fail: false
```
- `should_be_changed` : comparé à l'état `changed` réel. Avec un mock, c'est `consider_changed` qui le décide.
- `should_be_skipped` : `true` = le `when:` doit être faux ; `false` = la tâche doit vraiment tourner (utile pour prouver qu'une branche est atteinte).
- `should_fail: true` :
  - la tâche réussit → échec du scénario (« was expected to fail but succeeded ») ; sautée → échec aussi ;
  - la tâche échoue → message « failed as expected », puis le playbook **s'arrête avec le code 0** (les tâches suivantes ne sont pas testées), sauf si la tâche a `ignore_errors: true` ou est dans un `block` avec `rescue` : alors le playbook continue.
- `should_fail: false` écrit explicitement : une tâche qui échoue fait échouer le scénario avec un message clair (« failed and was not expected to »). Sans la clé, l'échec Ansible normal suffit (code non nul).
- Valeurs acceptées : booléen YAML ou `"true"`/`"false"`/`"1"`/`"0"` ; tout le reste compte comme `false`.

### block / rescue (depuis 1.5.0)
```yaml
- name: "Créer le POP"
  block:
    - name: "Appeler NetBox"
      netbox.netbox.netbox_site: { … }
  rescue:
    - name: "Prévenir l'équipe"
      ansible.builtin.debug:
        msg: "échec"
```
```yaml
- task: "Appeler NetBox"
  should_fail: true
- task: "Prévenir l'équipe"
  should_be_skipped: false
```
- Pour faire échouer exprès un module dans le test, simule-le avec un mock qui renvoie `failed: true` (voir `mock.md`).
- Bug ouvert #64 : `should_fail: true` sur la **dernière** tâche d'un `rescue:` (un `fail` qui relance l'erreur) est compté en échec en 1.7.1. Teste plutôt les tâches d'avant, ou dis à l'utilisateur que c'est un bug connu.
