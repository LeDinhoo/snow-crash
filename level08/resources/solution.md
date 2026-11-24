# Level08 — Socket et défaut d’authentification

## Objectif

Comprendre comment deux programmes communiquent par un socket Unix et comment une mauvaise gestion des états peut compromettre l’authentification. Le format binaire et le checksum sont nécessaires pour parler au service, mais la faille principale est un contrôle d’autorisation insuffisant.

## 1. Découvrir le service

```bash
id
find /opt/snowcrash/level08 -maxdepth 3 -ls
```

Les notes indiquent que `level08` appartient au groupe `blacksun`. Deux fichiers intéressants sont présents :

```text
/opt/snowcrash/level08/blacksun
/opt/snowcrash/level08/blacksun.c
```

Le second contient le code source qui définit le protocole du service :

```bash
cat /opt/snowcrash/level08/blacksun.c
```

Le source révèle notamment :

- le socket `/run/blacksun/blacksun.sock` ;
- les commandes `HELLO`, `AUTH` et `ADMIN` ;
- le format des messages ;
- la logique du checksum ;
- le chemin `/home/flag08/.flag` ;
- la vérification d’état incorrecte.

Une présentation complète devra conserver depuis la VM les extraits de `blacksun.c` qui définissent le format et la faille.

## 2. Comprendre le socket Unix

Un socket est un canal de communication entre deux programmes. Ici, le client et Black Sun communiquent localement par un socket Unix :

```text
client Python
    │
    │ messages binaires
    ▼
/run/blacksun/blacksun.sock
    │
    ▼
service Black Sun
```

Le groupe `blacksun` possède les permissions nécessaires pour contacter ce socket. L’autorisation des opérations administratives dépend ensuite du contrôle d’état implémenté par le service.

La solution exploite le contrôle d’état et laisse intacte la clé `/etc/blacksun/auth.key`.

## 3. Comprendre les états d’authentification

Un protocole correct doit distinguer plusieurs étapes :

```text
connexion initiale
        │
        ▼
identification du client
        │
        ▼
preuve d’authentification vérifiée
        │
        ▼
autorisation des commandes protégées
```

Dans le code étudié, `HELLO` fait passer l’état interne de la connexion à `AUTH`. La macro `CHECK_STATE` utilisée pour `ADMIN` accepte ensuite un état supérieur ou égal à `AUTH`, au lieu d’exiger que l’authentification administrative soit réellement terminée.

La séquence devient donc :

```text
HELLO → état AUTH → ADMIN accepté
```

La séquence utile se limite à `HELLO`, puis `ADMIN`. L’état intermédiaire obtenu après `HELLO` est traité à tort comme une autorisation suffisante.

## 4. Comprendre l’encodage binaire

Le client [client.py](client.py) utilise deux modules de la bibliothèque standard :

```python
import socket
import struct
```

| Module | Rôle |
| --- | --- |
| `socket` | Se connecter au socket Unix et échanger des octets. |
| `struct` | Encoder des entiers Python dans le format binaire attendu par le programme C. |

Exemple indépendant du protocole :

```python
import struct
print(struct.pack("<H", 258).hex(" "))
```

Résultat :

```text
02 01
```

`H` représente un entier non signé de 16 bits. Le symbole `<` impose l’ordre *little-endian*, dans lequel l’octet de poids faible est placé en premier. La valeur `258`, soit `0x0102`, devient donc `02 01`.

## 5. Comprendre le checksum

Le client reproduit la formule du code C :

```python
def checksum(payload):
    result = 0
    for index, byte in enumerate(payload):
        result ^= byte ^ (index & 0xFF)
    return result
```

L’opérateur `^` réalise un XOR bit à bit : un bit vaut `1` lorsque les deux bits comparés sont différents.

Pour le payload `ad de`, le calcul est :

```text
(0xad XOR 0) XOR (0xde XOR 1) = 0x72
```

Le checksum contrôle la structure et l’intégrité du message. L’identité de l’expéditeur doit être vérifiée séparément par le mécanisme d’authentification.

## 6. Construire l’en-tête

Le premier octet combine la version, l’état et la commande :

```python
first_byte = VERSION | (state << 3) | (command << 5)
```

Les autres champs sont encodés ainsi :

```python
header = bytes([first_byte]) + struct.pack(
    "<IHB", len(payload), checksum(payload), 0
)
```

| Élément | Taille | Rôle |
| --- | ---: | --- |
| `first_byte` | 1 octet | Version, état et commande combinés. |
| `I` | 4 octets | Longueur du payload. |
| `H` | 2 octets | Checksum. |
| `B` | 1 octet | Octet réservé, fixé à zéro. |

L’en-tête complet mesure donc huit octets.

### Message `HELLO`

Le premier message utilise la commande `HELLO`, l’état initial et le payload `0xDEAD` encodé en little-endian :

```text
en-tête : 01 02 00 00 00 72 00 00
payload : ad de
```

- `01` combine la version `1`, l’état `0` et la commande `0` ;
- `02 00 00 00` représente une longueur de deux octets ;
- `72 00` représente le checksum `0x72` ;
- le dernier `00` est l’octet réservé.

### Message `ADMIN`

Le second message ne contient aucun payload :

```text
49 00 00 00 00 00 00 00
```

`0x49` combine la version `1`, l’état `1` et la commande `ADMIN` numérotée `2` :

```text
1 | (1 << 3) | (2 << 5) = 0x49
```

## 7. Comprendre le client

Le script se décompose en quatre responsabilités :

| Partie | Rôle |
| --- | --- |
| `checksum()` | Calculer la valeur de contrôle du payload. |
| `struct.pack()` | Encoder les champs numériques dans l’ordre attendu. |
| `sock.sendall()` | Envoyer l’intégralité de chaque message. |
| `sock.recv()` | Lire les réponses du service. |

Le bloc `with socket.socket(...) as sock` garantit la fermeture du socket à la sortie du bloc, y compris si une erreur se produit.

## 8. Exécuter le client

Dans la session existante sous `level08`, créer le client et y coller le contenu exact de [client.py](client.py) :

```bash
vi /tmp/blacksun_client.py
```

Lancer ensuite le client :

```bash
python3 /tmp/blacksun_client.py
```

Résultat rapporté :

```text
HELLO OK
ACCESS GRANTED
FLAG=s5cAhoAfNT9GrgqykhZavyBg9
```

## 9. Passer à `level09`

```bash
su - level09
```

Saisir le secret comme mot de passe, puis vérifier l’identité obtenue :

```bash
id -un
```

Résultat attendu : `level09`. Le passage au compte suivant a réussi avec la valeur récupérée, également conservée dans `level08/flag`.

## Pourquoi cette méthode fonctionne

Le service confond progression dans le protocole et authentification réussie. `HELLO` place la connexion dans un état qui satisfait déjà la condition trop permissive d’`ADMIN`. Le client respecte le format binaire et le checksum attendus, puis cette condition autorise la commande.

L’erreur se situe dans la logique métier et le contrôle d’autorisation. Le XOR et le socket Unix servent uniquement au transport du message.

## Limites et portabilité

Le code C utilise des champs de bits dont l’organisation dépend de l’ABI. Les octets documentés correspondent à la VM x86_64 du niveau ; une autre ABI peut produire un ordre différent. Le client impose explicitement le little-endian pour les autres champs avec le préfixe `<` de `struct`.

La vérification locale couvre la syntaxe du client et les octets générés. La VM fournit la validation du service, de sa réponse et du flag.

## À expliquer à l’évaluation

> J’ai lu le code source pour reconstruire le protocole. `HELLO` fait passer la connexion à l’état `AUTH`, puis la vérification d’`ADMIN` accepte déjà cet état. Mon client encode deux messages conformes et calcule leur checksum. La séquence `HELLO` puis `ADMIN` obtient donc le flag, puis `su` permet de passer à `level09`.

## Traçabilité et références

Conserver les permissions du socket, les extraits de `blacksun.c` définissant l’en-tête, le checksum et `CHECK_STATE`, les octets envoyés, les réponses du service et le résultat de `id -un`.

Références utiles : [Python — `socket`](https://docs.python.org/3/library/socket.html#socket.AF_UNIX), [Python — `struct`](https://docs.python.org/3/library/struct.html) et [GCC — organisation des champs de bits](https://gcc.gnu.org/onlinedocs/gcc/Structures-unions-enumerations-and-bit-fields-implementation.html).
