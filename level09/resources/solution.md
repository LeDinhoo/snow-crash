# Level09 — Trouver un token dans un binaire

**Point de départ :** une session sur la VM Snow Crash sous `level09`. Le flag de ce niveau sert de mot de passe au compte `level10`.

## Objectif

Comprendre qu’un binaire peut contenir des chaînes de caractères lisibles, puis distinguer une simple chaîne intéressante d’un token réellement accepté par le programme.

## 1. Lire l’indice

```bash
cat README
```

Résultat de référence (à confirmer sur la VM) :

```text
Da5id saw something he shouldn't have.
```

Le nom `Da5id` oriente vers le programme à examiner ; `strings` permet ensuite d’y rechercher le token.

## 2. Localiser et identifier le programme

```bash
id
find /opt/snowcrash/level09 -maxdepth 3 -ls
```

Chemin à rechercher :

```text
/opt/snowcrash/level09/da5id
```

Vérifier sa nature et ses permissions :

```bash
file /opt/snowcrash/level09/da5id
ls -l /opt/snowcrash/level09/da5id
```

Vérifier les conditions suivantes :

- `da5id` est un exécutable ;
- il appartient à `flag09` ;
- il possède le bit setuid ;
- `level09`, membre du groupe `da5id`, peut l’exécuter.

Le `s` dans les permissions indique le bit setuid. À l’exécution, le programme peut recevoir l’UID effectif de son propriétaire, ici `flag09`, et lire un fichier inaccessible directement à `level09`.

## 3. Extraire les chaînes imprimables

```bash
strings /opt/snowcrash/level09/da5id
```

`strings` parcourt un fichier et affiche les séquences d’octets qui ressemblent à du texte imprimable. Cette commande est plus adaptée que `cat` à l’examen rapide d’un binaire, car elle écarte la majorité des octets non textuels.

Chaîne à rechercher dans la sortie :

```text
Iheartpwnage
```

La présence de la chaîne ne suffit pas à prouver qu’il s’agit du token : il faut tester son acceptation.

## 4. Tester le token

Passer la chaîne trouvée comme argument du programme :

```bash
/opt/snowcrash/level09/da5id Iheartpwnage
```

Résultat de référence (à confirmer sur la VM) :

```text
TOKEN ACCEPTED.
```

Flag de référence à comparer à la sortie du programme :

```text
s19q3m3u4toaequegh8ahpicel
```

`Iheartpwnage` contient 12 caractères. Les messages `checking byte 0...` à `checking byte 11...` restent à confirmer dans la sortie complète avant de conclure sur la vérification de chaque caractère.

Si ce message est effectivement affiché, le programme accepte la chaîne comme token.