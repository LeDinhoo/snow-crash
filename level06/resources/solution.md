# Level06 — Perl et expressions régulières

## Objectif

Nous sommes connectés en tant que `level06`. Notre objectif est de récupérer le secret situé dans `/home/flag06/.flag`, afin de passer au niveau suivant. Nous ne pouvons pas le lire directement : il faut trouver un programme qui peut le lire pour nous.

Dans ce niveau, nous allons découvrir qu’un fichier de configuration (un fichier de réglages) peut contenir du code exécuté par un programme ayant plus de droits que nous.

## 1. Trouver le programme

```bash
cat README
```

Résultat :

```text
Nothing passes through the Raven unread.
```

Le mot `Raven` fournit la piste : il semble désigner un programme à examiner. Nous ne connaissons pas encore la faille. Rechercher les fichiers correspondants dans le dossier du niveau :

```bash
find /opt/snowcrash/level06 -maxdepth 3 -ls
```

Deux fichiers intéressants apparaissent :

```text
/opt/snowcrash/level06/raven
/opt/snowcrash/level06/raven.pl
```

Le premier est l’exécutable à lancer. Le second est un script Perl lisible qui permet d’étudier le traitement réalisé. Perl est un langage de programmation, comme Python ou C. Raven analyse des logs, c’est-à-dire des fichiers qui enregistrent les événements de la machine.

## 2. Examiner les permissions

```bash
id
ls -l /etc/raven/raven.conf
ls -l /opt/snowcrash/level06/raven
```

`id` permet de connaître notre utilisateur et ses groupes. `ls -l` permet de voir les propriétaires et les permissions des fichiers. Nous cherchons à savoir si nous pouvons modifier les réglages de Raven et avec quels droits Raven s’exécute.

Les observations conservées montrent que :

- `level06` appartient au groupe `raven` ;
- ce groupe peut modifier `/etc/raven/raven.conf` ;
- l’exécutable `raven` appartient à `flag06` et possède le bit setuid.

Le bit setuid est visible par un `s` dans les permissions du propriétaire. Lors de l’exécution, le programme reçoit l’UID effectif de son propriétaire, ici `flag06`, tandis que la session reste ouverte sous `level06`.

Autrement dit, même si nous restons connectés en tant que `level06`, Raven dispose des droits effectifs de `flag06`. Nous pouvons modifier ses réglages : reste à savoir si ces réglages permettent de lui faire réaliser une opération imprévue.

Pour comprendre le setuid, rechercher `Linux setuid permissions` ou consulter [execve(2)](https://man7.org/linux/man-pages/man2/execve.2.html).

Les permissions exactes affichées par `ls -l` doivent être conservées depuis la VM afin d’apporter la preuve de ces affirmations.

## 3. Lire le script Perl

```bash
cat /opt/snowcrash/level06/raven.pl
```

Deux éléments sont déterminants :

```perl
use re 'eval';
```

et l’évaluation d’un motif provenant de la configuration :

```perl
$line =~ /$pattern/
```

Une expression régulière, ou *regex*, décrit un motif à rechercher dans du texte. Par exemple, si un journal contient `INFO: démarrage` et `ERROR: connexion impossible`, nous pouvons rechercher le mot `ERROR` pour identifier les erreurs. En Perl :

```perl
$line =~ /ERROR/
```

Cette expression vérifie si `$line` (la ligne du journal) contient le mot `ERROR`. L’opérateur `=~` applique l’expression régulière à cette ligne. Dans Raven, `$pattern` est lu dans le fichier de configuration modifiable par `level06`. Le réglage `loglevel_pattern` nous permet donc de choisir le motif recherché.

Pour comprendre cette syntaxe si l’on ne connaît pas Perl, rechercher `Perl regex =~ operator` et consulter le [tutoriel officiel des expressions régulières](https://perldoc.perl.org/perlretut).

## 4. Comprendre l’exécution de code dans la regex

La ligne `use re 'eval';` est notre indice principal. Si nous ne savons pas ce qu’elle signifie, nous pouvons rechercher exactement `Perl use re eval` sur Internet.

La [documentation officielle de re](https://perldoc.perl.org/re) explique que cette option autorise notamment du code dans un motif fourni par une variable. La [documentation perlre](https://perldoc.perl.org/perlre) décrit la syntaxe suivante :

```perl
(?{ code Perl })
```

Le code placé entre les accolades est exécuté pendant l’évaluation du motif. La directive `use re 'eval'` autorise ce mécanisme pour un motif construit dynamiquement.

Pour comprendre ce mécanisme, on peut faire un petit test indépendant de Raven :

```perl
use re 'eval';
my $pattern = q{(?{ print "Test OK\n" })};
my $line = "INFO: service started";
$line =~ /$pattern/;
```

`my` déclare une variable, `q{...}` conserve le texte du motif, et la dernière ligne applique ce motif. Le résultat est `Test OK` : le texte fourni comme motif a donc déclenché une instruction. Ce test ne lit aucun fichier secret.

La vulnérabilité vient de la combinaison suivante :

```text
configuration contrôlée par level06
                │
                ▼
 motif dynamique avec (?{ ... })
                │
                ▼
  use re 'eval' autorise son exécution
                │
                ▼
 Raven l’évalue avec les droits de flag06
```

## 5. Comprendre le rôle de la rétention

La configuration originale contient :

```ini
retention_days = 7
```

La rétention est la durée pendant laquelle les journaux sont pris en compte, exprimée ici en jours. Raven ignore les journaux trop anciens. Avec la configuration d’origine, les résultats rapportés sont :

```text
Total lines: 0
Skipped files: 2
```

Pourquoi est-ce important ? Même si notre motif contient du code, il ne sera pas évalué si Raven ne traite aucune ligne. C’est comme demander à quelqu’un de vérifier toutes les pages d’un livre alors qu’on ne lui donne aucune page.

L’exécution du motif nécessite au moins une ligne de journal traitée. La rétention initiale produit `Total lines: 0` ; elle doit donc être élargie en même temps que le motif est modifié.

La valeur `9999` élargit suffisamment la période pour inclure les journaux présents sur cette VM. Elle est choisie en fonction de l’âge des données du niveau.

## 6. Modifier la configuration

Nous savons maintenant que Perl peut exécuter du code dans le motif. Notre objectif est de lire un fichier. Pour savoir comment lancer une commande Linux depuis Perl, rechercher `Perl execute shell command`. La [documentation de system](https://perldoc.perl.org/functions/system) présente la fonction utilisée dans la solution.

Le réglage du motif contient donc une instruction Perl, qui demande à son tour de lancer `cat`. Nous conservons le dossier des journaux et augmentons la rétention pour que le motif soit effectivement utilisé.

Installer la configuration de test :

```bash
cat > /etc/raven/raven.conf <<'EOF'
log_dir = /var/log/snowcrash
retention_days = 9999
loglevel_pattern = (?{system('/bin/cat /home/flag06/.flag')})
EOF
```

| Réglage | Rôle |
| --- | --- |
| `log_dir` | Indiquer le dossier contenant les journaux à analyser. |
| `retention_days` | Autoriser le traitement des journaux anciens du niveau. |
| `loglevel_pattern` | Fournir le motif évalué par Perl. |
| `system(...)` | Demander à Perl de lancer la commande externe `cat`. |

Les apostrophes autour de `EOF` empêchent le shell de transformer le contenu avant son écriture.

## 7. Exécuter Raven

```bash
/opt/snowcrash/level06/raven
```

Nous lançons simplement Raven : c’est le programme qui lit la configuration et applique le motif aux lignes du journal. Selon le résultat rapporté dans les notes originales, le motif exécute `cat` avec les droits nécessaires pendant ce traitement et affiche le secret :

```text
wizelohxamaiuiia2uinaes4a
```
