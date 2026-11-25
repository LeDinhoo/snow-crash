# Level02 — Lire un fichier temporaire mal protégé

**Point de départ :** une session sur la VM Snow Crash sous `level02`. Le flag de ce niveau sert de mot de passe au compte `level03`.

## Objectif

Comprendre les conséquences d’une mauvaise gestion des permissions. La confidentialité d’un fichier temporaire dépend de son emplacement, de ses droits et de sa suppression après usage.

## 1. Lire l’indice

```bash
cat README
```

Résultat de référence (à confirmer sur la VM) :

```text
A Kourier never loses a package. Even after delivery.
```

Rechercher les chemins contenant `Kourier`, le mot-clé de l’indice.

## 2. Rechercher les chemins liés à l’indice

```bash
find / -iname '*kourier*' 2>/dev/null
```

| Élément | Rôle |
| --- | --- |
| `find /` | Parcourir le système de fichiers depuis sa racine. |
| `-iname '*kourier*'` | Ne retenir que les chemins dont le nom contient `kourier`, sans tenir compte de la casse. |
| `2>/dev/null` | Masquer les erreurs d’accès. |

Chemin à rechercher :

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

Vérifier que le fichier appartient à `flag02`, contient du texte et accorde le droit de lecture aux autres utilisateurs. Si ces droits sont confirmés, `level02` peut le lire.

## 4. Lire le contenu

```bash
cat /tmp/kourier_delivery.tmp
```

Flag de référence à comparer au contenu du fichier :

```text
qi0mauch9ahksha8b6dfe3p0kq
```

## 5. Passer à `level03`

Depuis `level02`, changer d’utilisateur avec la valeur récupérée :

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
