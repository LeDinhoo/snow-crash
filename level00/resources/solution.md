# Level00 — Trouver un secret dans un binaire

## Objectif

Comprendre qu’un programme compilé peut contenir des informations directement lisibles par analyse statique. Ici, le secret est stocké en clair dans une section d’un fichier ELF accessible à `level00`.

## 1. Ouvrir la session SSH

La connexion SSH est effectuée une seule fois, au début du projet, avec les identifiants fournis par le sujet :

```bash
ssh level00@<vm-ip> -p 4242
```

Mot de passe :

```text
level00
```

La même session reste ensuite ouverte. Les changements de niveau utilisent `su - levelNN` avec le flag obtenu.

## 2. Identifier son environnement

```bash
whoami
id
ls -la
```

Ces commandes permettent de connaître l’utilisateur courant, ses groupes et les fichiers immédiatement accessibles.

`whoami` indique que la session utilise le compte `level00`. Le chapitre V du sujet, **How progression works**, donne ensuite la règle de nommage :

- chaque niveau s’exécute sous un utilisateur `levelNN` ;
- le flag correspondant est lisible par le compte `flagNN` ;
- ce flag se trouve dans `/home/flagNN/.flag` et sert de mot de passe à `levelNN+1`.

Pour le niveau courant, `NN` vaut `00`. La règle de progression du sujet désigne donc `flag00` comme compte cible.

On peut vérifier cette convention dans la base des utilisateurs de la VM :

```bash
getent passwd | grep -E '^(level|flag)[0-9]{2}:'
getent passwd flag00
```

La première commande montre les séries parallèles `levelXX` et `flagXX`. La seconde confirme précisément l’existence de `flag00` sur la VM.

## 3. Rechercher les fichiers appartenant à `flag00`

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

Un fichier appartenant à `flag00` peut contenir un programme, une configuration ou une donnée utile. L’étape suivante consiste à examiner ses droits et son contenu.

## 4. Identifier le fichier

```bash
ls -l /opt/snowcrash/level00/hiro
file /opt/snowcrash/level00/hiro
```

- `ls -l` permet de contrôler le propriétaire, le groupe et les droits d’accès. Les observations conservées indiquent que `hiro` est lisible par le groupe `level00`.
- `file` identifie la nature du fichier avant de choisir un outil d’analyse. Ici, il s’agit d’un fichier ELF.

ELF signifie *Executable and Linkable Format*. C’est le format couramment utilisé par les exécutables, les bibliothèques et les fichiers objets sous Linux. Un fichier ELF est organisé en différentes sections, dont certaines peuvent contenir du code et d’autres des données.

## 5. Repérer une donnée intéressante

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

Le nom `.flag_data` oriente l’analyse vers cette section. La lecture de son contenu permet de confirmer son rôle.

## 6. Lire la section `.flag_data`

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

L’analyse statique porte directement sur les données enregistrées dans `hiro`.

## 7. Passer à `level01`

Conserver la session SSH ouverte et changer d’utilisateur avec la valeur récupérée :

```bash
su - level01
```

Saisir le flag comme mot de passe, puis vérifier l’identité obtenue :

```bash
id -un
```

Résultat attendu :

```text
level01
```