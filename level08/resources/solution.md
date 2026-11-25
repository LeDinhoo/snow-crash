# Level08 — Contourner une authentification par un défaut d’état

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

Les observations conservées indiquent que `level08` appartient au groupe `blacksun`. Deux fichiers sont particulièrement intéressants :

| Fichier | Explication |
| --- | --- |
| `/opt/snowcrash/level08/blacksun` | Le programme exécutable. |
| `/opt/snowcrash/level08/blacksun.c` | Le code source qui décrit son fonctionnement. |

Nous lisons le code source :

```bash
cat /opt/snowcrash/level08/blacksun.c
```

Il révèle notamment :

- le socket `/run/blacksun/blacksun.sock` ;
- les commandes `HELLO`, `AUTH` et `ADMIN` ;
- le format binaire des messages ;
- le calcul du checksum ;
- le chemin `/home/flag08/.flag` ;
- la vérification incorrecte de l’état de la connexion.

Lire ce fichier revient à consulter le plan d’un coffre-fort : nous pouvons étudier chaque mécanisme pour chercher une erreur de conception.

## 2. Comprendre le socket Unix

Un socket est un canal qui permet à deux programmes de communiquer. Nous pouvons le comparer à une ligne téléphonique locale : notre client appelle Black Sun, puis les deux programmes échangent des messages.

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

Le groupe `blacksun` possède les permissions nécessaires pour contacter ce socket. Cela nous donne le droit de parler au service, mais pas automatiquement celui d’accéder à ses informations protégées.

Cette différence est importante :

- **communiquer** signifie pouvoir envoyer des messages au programme ;
- **s’authentifier** signifie prouver son identité ;
- **être autorisé** signifie avoir le droit d’effectuer une action précise.

La clé `/etc/blacksun/auth.key` sert normalement à l’authentification. La solution ne la lit pas et ne la modifie pas.

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

Dans le code étudié, `HELLO` place la connexion dans un état nommé `AUTH`. Cet état devrait seulement signifier **« en attente d’authentification »**.

Cependant, la macro `CHECK_STATE` utilisée pour `ADMIN` accepte déjà un état supérieur ou égal à `AUTH`. Le service confond donc le fait d’avoir atteint l’étape d’authentification avec le fait de l’avoir réussie.

La séquence suivante suffit alors :

```text
HELLO → état AUTH → ADMIN accepté
```

La commande `AUTH` et la preuve d’identité sont entièrement sautées.

Imaginons une banque : nous disons bonjour à l’agent de sécurité, qui devrait ensuite nous demander une pièce d’identité. Mais il considère par erreur que le simple fait d’être arrivé à l’étape du contrôle signifie que notre identité a déjà été validée. Il nous laisse donc entrer dans la zone protégée sans effectuer le contrôle.

## 4. Pourquoi utiliser un script Python ?

Connaître la faille ne suffit pas : il faut encore envoyer les commandes dans le format exact attendu par Black Sun.

Le service n’attend pas directement le texte suivant :

```text
HELLO
ADMIN
```

Il attend des messages binaires composés d’un en-tête et, parfois, d’un contenu. Le fichier [client.py](client.py) sert donc de traducteur entre nos intentions et le protocole de Black Sun.

Il utilise deux modules de la bibliothèque standard de Python :

```python
import socket
import struct
```

| Module | Rôle |
| --- | --- |
| `socket` | Ouvrir la communication avec Black Sun et échanger des octets. |
| `struct` | Encoder les nombres dans le format binaire attendu par le programme C. |

Le script ne crée pas la faille. Il automatise simplement l’envoi des deux messages qui permettent de l’exploiter.

## 5. Comprendre la structure d’un message

Un message peut être comparé à un colis : l’en-tête est son étiquette et le payload est son contenu.

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

Le checksum est une valeur de contrôle. Le service le recalcule à partir du payload, puis vérifie que le résultat correspond à celui placé dans l’en-tête.

Nous pouvons le comparer à un code de contrôle calculé à partir du contenu d’un colis. Si le contenu change pendant le transport, le code recalculé à l’arrivée ne correspond plus. Le vrai calcul est différent, mais son rôle reste de détecter une incohérence dans le message.

Le client reproduit la formule trouvée dans le code C :

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

Black Sun répond `HELLO OK` et place la connexion dans l’état `AUTH`.

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

Le script [client.py](client.py) effectue les actions suivantes :

1. Il ouvre une connexion vers `/run/blacksun/blacksun.sock`.
2. Il construit le message `HELLO` dans le bon format.
3. Il calcule le checksum du payload et envoie le message.
4. Il lit la réponse `HELLO OK`.
5. Il construit et envoie directement le message `ADMIN`, sans envoyer de commande `AUTH`.
6. Il lit la réponse administrative et le secret affiché par le service.

Les fonctions principales ont chacune un rôle précis :

| Partie | Rôle |
| --- | --- |
| `checksum()` | Calculer la valeur de contrôle du payload. |
| `struct.pack()` | Encoder les champs numériques dans l’ordre attendu. |
| `sock.sendall()` | Envoyer l’intégralité du message. |
| `sock.recv()` | Lire les réponses du service. |

Le bloc `with socket.socket(...) as sock` ferme automatiquement le socket à la fin, même si une erreur se produit.

## 10. Exécuter le client

Dans la session ouverte avec `level08`, nous créons un fichier temporaire et y copions le contenu exact de [client.py](client.py) :

```bash
vi /tmp/blacksun_client.py
```

Nous lançons ensuite le script :

```bash
python3 /tmp/blacksun_client.py
```

Résultat rapporté :

```text
HELLO OK
ACCESS GRANTED
FLAG=s5cAhoAfNT9GrgqykhZavyBg9
```

Le service nous donne le secret sans que nous ayons fourni la clé d’authentification.