# Level09 — Trouver un token dans un binaire

## Objectif

Comprendre qu’un binaire peut contenir des chaînes de caractères lisibles, puis distinguer une simple chaîne intéressante d’un token réellement accepté par le programme.

## 1. Lire l’indice

```bash
cat README
```

Résultat :

```text
Da5id saw something he shouldn't have.
```

Le nom `Da5id` oriente vers le programme à examiner ; `strings` permet ensuite d’y rechercher le token.

## 2. Localiser et identifier le programme

```bash
id
find /opt/snowcrash/level09 -maxdepth 3 -ls
```

Le fichier intéressant est :

```text
/opt/snowcrash/level09/da5id
```

Vérifier sa nature et ses permissions :

```bash
file /opt/snowcrash/level09/da5id
ls -l /opt/snowcrash/level09/da5id
```

Les observations conservées montrent que :

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

La chaîne intéressante rapportée est :

```text
Iheartpwnage
```

Une chaîne présente dans un programme peut être un message, un chemin, une donnée de test ou un secret. `Iheartpwnage` devient donc une candidate à tester avec le programme.

## 4. Tester le token

Passer la chaîne trouvée comme argument du programme :

```bash
/opt/snowcrash/level09/da5id Iheartpwnage
```

Résultat rapporté :

```text
TOKEN ACCEPTED.
```

Le programme affiche ensuite le flag :

```text
s19q3m3u4toaequegh8ahpicel
```

`Iheartpwnage` contient 12 caractères. Les messages `checking byte 0...` à `checking byte 11...` indiquent que le programme contrôle chacun de ces caractères avant d’accepter le token.

Le message `TOKEN ACCEPTED.` confirme que la chaîne constitue l’entrée attendue.