# Snow Crash — suivi

Cible autorisée : la VM Snow Crash de 42. La progression suit le chemin d’exploitation prévu par chaque niveau. Chaque flag est enregistré après le passage au compte suivant ; aucun binaire n’est copié dans le dépôt.

La connexion SSH est ouverte une seule fois avec `level00`. Les niveaux suivants sont atteints dans cette session avec `su - levelNN`.

| Niveau | État | Solution |
| --- | --- | --- |
| level00 | Résolu | Secret extrait de la section ELF `.flag_data`, puis passage à `level01` confirmé. Voir `level00/resources/solution.md`. |
| level01 | Résolu | Secret exposé dans la ligne de commande du service Gargoyle, puis passage à `level02` confirmé. Voir `level01/resources/solution.md`. |
| level02 | Résolu | Secret laissé dans un fichier temporaire lisible par tous, puis passage à `level03` confirmé. Voir `level02/resources/solution.md`. |
| level03 | Résolu | Script CMake chargé par le service Burbclave, puis passage à `level04` confirmé. Voir `level03/resources/solution.md`. |
| level04 | Résolu | Macro M4 exécutée par le service Babel, puis passage à `level05` confirmé. Voir `level04/resources/solution.md`. |
| level05 | Résolu | Module WASM modifiable exécuté par le service Metaverse, puis passage à `level06` confirmé. Voir `level05/resources/solution.md`. |
| level06 | Résolu | Motif Perl modifiable dans la configuration de Raven, puis passage à `level07` confirmé. Voir `level06/resources/solution.md`. |
| level07 | Résolu | Évasion du jail Python par introspection d’objets, puis passage à `level08` confirmé. Voir `level07/resources/solution.md`. |
| level08 | Résolu | Requête au socket Black Sun : le contrôle d’état autorise `ADMIN` après `HELLO`, puis passage à `level09` confirmé. Voir `level08/resources/solution.md`. |
| level09 | Résolu | Chaîne `Iheartpwnage` extraite du binaire Da5id et acceptée comme token, puis passage à `level10` confirmé. Voir `level09/resources/solution.md`. |
| level10 | Résolu | Module WASM modifiable → validation QuickJS → injection via `std.popen`; confirmé par le flag lu par le lanceur setuid. Voir level10/resources/solution.md. |
