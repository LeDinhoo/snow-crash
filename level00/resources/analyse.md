# Level00

Les notes citent le compte cible `flag00`, sans expliquer comment il a été identifié. On ne peut pas reconstituer cette première découverte avec le dépôt seul.

À partir de cette piste, chercher ses fichiers :

```sh
find / -type f -user flag00 -print 2>/dev/null
```

Le chemin consigné est `/opt/snowcrash/level00/hiro`. Vérifier ses droits, puis lister ses sections :

```sh
ls -l /opt/snowcrash/level00/hiro
readelf -S /opt/snowcrash/level00/hiro
```

C'est dans cette liste qu'on doit découvrir `.flag_data`, avant de demander son contenu. Son nom suggère une piste, pas encore une preuve :

```sh
objdump -s -j .flag_data /opt/snowcrash/level00/hiro
```

La solution rapporte le secret `f2av5il02puano7naaf6adaf3a`, identique au fichier `flag`. Le défaut est un secret en clair dans un binaire lisible : pas besoin de lancer le programme pour lire ses données.

Vérifier le secret par une connexion, puis contrôler l'identité avec `id -un` :

```sh
ssh -p 4242 level01@localhost
```

Résultat attendu : `level01`. La solution rapporte ce succès ; je ne l'ai pas reproduit. Le binaire et les sorties originales manquent. `readelf -S` est l'étape de découverte proposée pour combler le saut des notes, pas une commande déjà vérifiée sur la VM.

À l'oral : expliquer comment chaque commande fournit la piste utilisée par la suivante. Conserver cette note et la solution suffit ; aucun script n'est nécessaire.
