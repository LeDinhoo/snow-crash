# Level01 — Trouver un secret dans un processus

**Point de départ :** une session sur la VM Snow Crash sous `level01`. Le flag de ce niveau sert de mot de passe au compte `level02`.

## Objectif

Comprendre qu’un programme peut accidentellement exposer des informations confidentielles dans ses arguments de lancement. Un processus peut appartenir à un autre utilisateur tout en laissant sa ligne de commande visible.

## 1. Lire l’indice

```bash
cat README
```

Résultat de référence (à confirmer sur la VM) :

```text
Gargoyles never stop collecting.
```

L’indice suggère de rechercher un processus ou un service nommé `gargoyle`.

## 2. Rechercher le processus

Rechercher le processus :

```bash
ps -ef | grep -i gargoyle
```

| Élément | Rôle |
| --- | --- |
| `ps -ef` | Afficher les processus du système avec leur propriétaire et leur ligne de commande. |
| `|` | Transmettre la sortie de `ps` à la commande suivante. Ce caractère est appelé un *pipe*. |
| `grep -i gargoyle` | Ne conserver que les lignes contenant `gargoyle`, sans tenir compte de la casse. |

Cette forme peut aussi afficher le processus `grep` utilisé pour la recherche. Le motif suivant évite normalement ce résultat parasite :

```bash
ps -ef | grep '[g]argoyle'
```

Le motif `[g]argoyle` correspond toujours au mot `gargoyle`, mais la ligne de commande de `grep` contient littéralement les crochets. Elle ne correspond donc normalement pas à son propre filtre.

## 3. Examiner le service

```bash
systemctl status gargoyle.service --no-pager
```

Un service est un programme généralement exécuté en arrière-plan et géré ici par `systemd`. L’option `--no-pager` affiche directement toute la sortie dans le terminal.

Informations à confirmer dans les sorties de `ps` et `systemctl` :

| Information | Valeur de référence |
| --- | --- |
| Propriétaire du processus | `flag01` |
| Programme | `gargoyle` |
| Argument visible | `kooda7puivaav1idi4f57q8iq0` |

Si l’argument est visible, il fournit directement le secret.

## 4. Passer à `level02`

Depuis `level01`, changer d’utilisateur avec l’argument récupéré :

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
