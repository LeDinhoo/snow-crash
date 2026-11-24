# Level02 — Lire un fichier temporaire mal protégé

## Objectif

Comprendre les conséquences d’une mauvaise gestion des permissions. La confidentialité d’un fichier temporaire dépend de son emplacement, de ses droits et de sa suppression après usage.

## 1. Lire l’indice

```bash
cat README
```

Résultat :

```text
A Kourier never loses a package. Even after delivery.
```

L’indice suggère qu’une information reste présente après avoir été utilisée ou « livrée ». On peut donc rechercher un fichier oublié appartenant au compte cible.

## 2. Rechercher les fichiers de `flag02`

```bash
find / -path /proc -prune -o -type f -user flag02 -print 2>/dev/null
```

| Élément | Rôle |
| --- | --- |
| `find /` | Parcourir le système de fichiers depuis sa racine. |
| `-path /proc -prune` | Ne pas descendre dans `/proc`. |
| `-o` | Évaluer l’expression située à droite pour les autres chemins. |
| `-type f` | Ne retenir que les fichiers ordinaires. |
| `-user flag02` | Ne retenir que les fichiers appartenant à `flag02`. |
| `-print` | Afficher les chemins correspondants. |
| `2>/dev/null` | Masquer les erreurs d’accès. |

`/proc` est un système de fichiers virtuel qui expose notamment des informations sur les processus. L’exclure évite des résultats instables et des erreurs inutiles pendant cette recherche.

Le résultat intéressant est :

```text
/tmp/kourier_delivery.tmp
```

Le répertoire `/tmp` sert aux fichiers temporaires. Les permissions du fichier trouvé déterminent quels utilisateurs peuvent le lire.

## 3. Vérifier la nature et les droits du fichier

```bash
ls -l /tmp/kourier_delivery.tmp
file /tmp/kourier_delivery.tmp
```

- `ls -l` affiche notamment le propriétaire et les droits d’accès ;
- `file` détermine le type de contenu sans se fier uniquement à l’extension.

Les observations conservées indiquent que le fichier appartient à `flag02`, contient du texte et accorde le droit de lecture aux autres utilisateurs. `level02` est donc autorisé par le système à le lire.

## 4. Lire le contenu

```bash
cat /tmp/kourier_delivery.tmp
```

Le fichier révèle le secret :

```text
qi0mauch9ahksha8b6dfe3p0kq
```

Le droit de lecture accordé à `level02` permet d’afficher directement le contenu avec `cat`.

## 5. Passer à `level03`

Dans la session existante, changer d’utilisateur avec la valeur récupérée :

```bash
su - level03
```

Saisir le secret comme mot de passe, puis vérifier l’identité obtenue :

```bash
id -un
```

Résultat attendu :

```text
level03
```

Le passage à `level03` a réussi avec cette valeur. Le secret est également conservé dans le fichier `level02/flag` du dépôt.

## Pourquoi cette méthode fonctionne

Le propriétaire a laissé une information confidentielle dans un fichier temporaire lisible par les autres utilisateurs. Les permissions trop larges et la conservation du fichier après usage exposent son contenu.

Un fichier sensible devrait être créé avec des droits restrictifs, dans un emplacement approprié, puis supprimé dès qu’il n’est plus nécessaire.

## À expliquer à l’évaluation

> L’indice suggérait qu’un « paquet » restait présent après sa livraison. J’ai recherché les fichiers appartenant à `flag02`, puis vérifié les droits du fichier temporaire découvert. Les permissions accordées permettaient directement à `level02` de lire le secret.

## Traçabilité à conserver

Conserver les sorties de `find`, `ls -l`, `file` et `id -un` permet de démontrer chaque transition de la démarche : découverte du fichier, vérification de son type, preuve du droit de lecture et validation du compte obtenu.
