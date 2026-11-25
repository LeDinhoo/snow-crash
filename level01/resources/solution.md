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