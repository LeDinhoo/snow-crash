# Level00 — Trouver un secret dans un binaire

## Objectif

Comprendre qu’un programme compilé peut contenir des informations lisibles sans qu’il soit nécessaire de l’exécuter. Ici, le secret est stocké en clair dans une section d’un fichier ELF accessible à `level00`.

## 1. Identifier son environnement

```bash
whoami
id
ls -la
```

Ces commandes permettent de connaître l’utilisateur courant, ses groupes et les fichiers immédiatement accessibles.

Les notes de résolution désignent directement `flag00` comme compte cible, mais ne conservent pas l’indice qui a permis de l’identifier. Sur la VM, on peut au moins vérifier que ce compte existe :

```bash
getent passwd flag00
```

Cette vérification confirme une piste ; elle n’explique pas, à elle seule, comment le nom `flag00` a été découvert.

## 2. Rechercher les fichiers appartenant à `flag00`

```bash
find / -type f -user flag00 -print 2>/dev/null
```

| Élément | Rôle |
| --- | --- |
| `find /` | Parcourir le système de fichiers depuis sa racine. |
| `-type f` | Ne retenir que les fichiers ordinaires. |
| `-user flag00` | Ne retenir que les fichiers appartenant à `flag00`. |
| `-print` | Afficher chaque chemin trouvé. |
| `2>/dev/null` | Masquer les erreurs d’accès envoyées sur la sortie d’erreur. |

Le résultat intéressant est :

```text
/opt/snowcrash/level00/hiro
```

On recherche les fichiers de `flag00` parce qu’un fichier appartenant au compte cible peut contenir un programme, une configuration ou une donnée utile. Le fait qu’un fichier appartienne à `flag00` n’est toutefois pas une preuve : il faut encore vérifier ses droits et son contenu.

## 3. Identifier le fichier

```bash
ls -l /opt/snowcrash/level00/hiro
file /opt/snowcrash/level00/hiro
```

- `ls -l` permet de contrôler le propriétaire, le groupe et les droits d’accès. Les observations conservées indiquent que `hiro` est lisible par le groupe `level00`.
- `file` identifie la nature du fichier avant de choisir un outil d’analyse. Ici, il s’agit d’un fichier ELF.

ELF signifie *Executable and Linkable Format*. C’est le format couramment utilisé par les exécutables, les bibliothèques et les fichiers objets sous Linux. Un fichier ELF est organisé en différentes sections, dont certaines peuvent contenir du code et d’autres des données.

## 4. Repérer une donnée intéressante

Commencer par examiner les symboles du binaire :

```bash
nm -S /opt/snowcrash/level00/hiro
```

`nm` affiche les symboles présents dans le fichier. Un symbole peut notamment désigner une fonction ou une donnée nommée. Les observations conservées signalent un symbole nommé `flag_data`.

Afficher ensuite la table des sections :

```bash
readelf -S /opt/snowcrash/level00/hiro
```

Cette liste fait apparaître une section inhabituelle :

```text
.flag_data
```

Son nom suggère qu’elle contient une donnée intéressante, mais le nom d’une section ne constitue pas encore une preuve. Il faut lire son contenu.

## 5. Lire la section `.flag_data`

```bash
objdump -s -j .flag_data /opt/snowcrash/level00/hiro
```

| Option | Rôle |
| --- | --- |
| `objdump` | Examiner le contenu d’un fichier objet ou exécutable. |
| `-s` | Afficher le contenu brut des sections sélectionnées. |
| `-j .flag_data` | Limiter l’affichage à la section `.flag_data`. |

Le contenu de cette section révèle le secret en clair :

```text
f2av5il02puano7naaf6adaf3a
```

Il n’est pas nécessaire de lancer `hiro`. L’analyse porte directement sur les données enregistrées dans le fichier.

## 6. Valider le secret

Utiliser la valeur récupérée comme mot de passe de `level01` :

```bash
ssh -p 4242 level01@localhost
```

Après la connexion, vérifier l’identité obtenue :

```bash
id -un
```

Résultat attendu :

```text
level01
```

La connexion à `level01` a réussi avec cette valeur ; le secret est également conservé dans le fichier `level00/flag` du dépôt.

## Pourquoi cette méthode fonctionne

Le développeur a placé un secret en clair dans un binaire lisible par notre utilisateur. Compiler un programme ne chiffre ni ne protège automatiquement les chaînes et les données qu’il embarque. Dès qu’un fichier est lisible, ses sections peuvent être inspectées avec des outils comme `readelf` et `objdump`.

Le programme `hiro` simule par ailleurs une invite dont certaines réponses sont codées en dur. L’exécuter peut donc détourner l’attention ; l’analyse statique du fichier fournit ici une preuve plus directe.

## À expliquer à l’évaluation

> J’ai recherché les fichiers appartenant à `flag00`, puis vérifié que `hiro` était un exécutable ELF lisible. Le symbole `flag_data` et la section `.flag_data` ont orienté l’analyse. J’ai affiché cette section avec `objdump` et récupéré le secret sans exécuter le programme, puis je l’ai validé en me connectant à `level01`.

## Traçabilité à compléter sur la VM

Pour rendre la résolution entièrement reproductible, conserver :

- l’indice initial qui permet d’identifier `flag00` comme compte cible ;
- les sorties de `ls -l`, `file`, `nm -S` et `readelf -S` ;
- la sortie utile de `objdump` ;
- le résultat de `id -un` après la connexion à `level01`.

Les commandes `file` et `readelf -S` explicitent la démarche de découverte, mais leurs sorties originales ne figurent pas dans les notes actuelles.
