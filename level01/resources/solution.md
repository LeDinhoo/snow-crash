# Level01 — Trouver un secret dans un processus

## Objectif

Comprendre qu’un programme peut accidentellement exposer des informations confidentielles dans ses arguments de lancement. Un processus peut appartenir à un autre utilisateur tout en laissant sa ligne de commande visible.

## 1. Lire l’indice

```bash
cat README
```

Résultat :

```text
Gargoyles never stop collecting.
```

Le mot `Gargoyles` fournit un nom à rechercher. L’expression *never stop* peut suggérer un programme qui fonctionne en permanence, donc un processus ou un service.

## 2. Rechercher le processus

Une première recherche peut être effectuée ainsi :

```bash
ps -ef | grep -i gargoyle
```

| Élément | Rôle |
| --- | --- |
| `ps -ef` | Afficher les processus du système avec leur propriétaire et leur ligne de commande. |
| `|` | Transmettre la sortie de `ps` à la commande suivante. Ce caractère est appelé un *pipe*. |
| `grep -i gargoyle` | Ne conserver que les lignes contenant `gargoyle`, sans tenir compte de la casse. |

Cette forme peut aussi afficher le processus `grep` utilisé pour la recherche. La commande retenue dans les notes évite ce bruit :

```bash
ps -ef | grep '[g]argoyle'
```

Le motif `[g]argoyle` correspond toujours au mot `gargoyle`, mais la ligne de commande de `grep` contient littéralement les crochets. Elle ne correspond donc normalement pas à son propre filtre.

## 3. Examiner le service

```bash
systemctl status gargoyle.service --no-pager
```

Un service est un programme généralement exécuté en arrière-plan et géré ici par `systemd`. L’option `--no-pager` affiche directement toute la sortie dans le terminal.

Les sorties conservées permettent d’établir les éléments suivants :

| Information | Valeur observée |
| --- | --- |
| Propriétaire du processus | `flag01` |
| Programme | `gargoyle` |
| Argument visible | `kooda7puivaav1idi4f57q8iq0` |

Le secret apparaît directement dans la ligne de commande du processus, accessible avec les commandes d’inspection précédentes.

## 4. Passer à `level02`

Dans la session existante, changer d’utilisateur avec l’argument récupéré :

```bash
su - level02
```

Saisir le secret comme mot de passe, puis vérifier l’identité obtenue :

```bash
id -un
```

Résultat attendu :

```text
level02
```

Le passage à `level02` a réussi avec cette valeur. Le secret est également conservé dans le fichier `level01/flag` du dépôt.

## Pourquoi cette méthode fonctionne

Les arguments de lancement restent visibles dans la liste des processus de cette VM. `level01` peut ainsi consulter la ligne de commande du processus exécuté par `flag01`.

L’erreur consiste à transmettre une information confidentielle comme argument. Un descripteur de fichier protégé ou un gestionnaire de secrets adapté permettrait de fournir cette valeur de manière confidentielle.

## À expliquer à l’évaluation

> L’indice m’a orienté vers un service nommé Gargoyle. J’ai affiché les processus, puis vérifié le service. Le programme fonctionne sous l’identité `flag01`, mais son secret est transmis dans un argument visible par `level01`. J’ai récupéré cet argument, puis je suis passé à `level02` avec `su`.

## Traçabilité à conserver

Pour rendre la résolution reproductible, conserver les sorties utiles de :

```bash
ps -ef | grep '[g]argoyle'
systemctl status gargoyle.service --no-pager
id -un
```

Les commandes d’inspection présentées suffisent pour résoudre ce niveau.
