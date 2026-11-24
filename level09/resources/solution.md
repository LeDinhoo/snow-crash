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

## 5. Passer à `level10`

```bash
su - level10
```

Saisir le flag comme mot de passe, puis vérifier l’identité obtenue :

```bash
id -un
```

Résultat attendu : `level10`. Le passage au compte suivant a réussi avec le flag affiché par `da5id`, également conservé dans `level09/flag`.

## Pourquoi cette méthode fonctionne

Le token a été intégré au binaire sous une forme lisible. `strings` permet de le repérer sans désassembler le programme. Le binaire setuid valide ensuite ce token avec les droits effectifs de `flag09`, ce qui lui permet de lire et d’afficher le flag.

L’analyse statique fournit une candidate significative, ensuite validée par le programme.

## Différence avec le Level00

Les deux niveaux examinent des données lisibles dans un fichier compilé, mais leur résultat intermédiaire diffère :

| Niveau | Donnée découverte | Étape suivante |
| --- | --- | --- |
| Level00 | Le flag lui-même dans une section ELF dédiée. | Utiliser directement le flag pour passer à `level01`. |
| Level09 | Un token accepté par le programme. | Exécuter `da5id` avec ce token pour obtenir le flag. |

## À expliquer à l’évaluation

> Le README m’a orienté vers le binaire `da5id`. Après avoir vérifié son type, ses permissions et son bit setuid, j’ai utilisé `strings` pour repérer `Iheartpwnage`. J’ai testé cette candidate une seule fois ; le programme a confirmé le token et affiché le flag avec les droits de `flag09`. J’ai ensuite utilisé `su` pour passer à `level10`.

## Traçabilité et références

Conserver les sorties de `id`, `find`, `file`, `ls -l`, la partie utile de `strings`, la réponse complète de `da5id` et le résultat de `id -un`.

Références utiles : [GNU Binutils — `strings`](https://sourceware.org/binutils/docs/binutils/strings.html) et [Linux man-pages — `execve(2)`](https://man7.org/linux/man-pages/man2/execve.2.html).
