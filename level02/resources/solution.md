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

L’indice donne surtout un mot-clé : `Kourier`. Plutôt que de supposer où se trouve le fichier, on recherche les chemins dont le nom contient ce mot.

## 2. Rechercher les chemins liés à l’indice

```bash
find / -iname '*kourier*' 2>/dev/null
```

| Élément | Rôle |
| --- | --- |
| `find /` | Parcourir le système de fichiers depuis sa racine. |
| `-iname '*kourier*'` | Ne retenir que les chemins dont le nom contient `kourier`, sans tenir compte de la casse. |
| `2>/dev/null` | Masquer les erreurs d’accès. |

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