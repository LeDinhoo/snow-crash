# Snow Crash — suivi

Cible autorisée : la VM Snow Crash de 42. Aucun brute-force SSH. Chaque flag est enregistré uniquement après validation; aucun binaire n’est copié dans le dépôt.

| Niveau | État | Solution |
| --- | --- | --- |
| level00 | Résolu | Secret extrait de la section ELF .flag_data et confirmé par la connexion à level01. Voir level00/resources/solution.md. |
| level01 | Résolu | Secret exposé dans la ligne de commande du service gargoyle et confirmé par la connexion à level02. Voir level01/resources/solution.md. |
| level02 | Résolu | Secret laissé dans un fichier temporaire lisible par tous et confirmé par la connexion à level03. Voir level02/resources/solution.md. |
| level03 | Résolu | Script CMake chargé par le service burbclave, puis connexion à level04 confirmée. Voir level03/resources/solution.md. |
| level04 | Résolu | Macro M4 exécutée par le service Babel, puis connexion à level05 confirmée. Voir level04/resources/solution.md. |
| level05 | Résolu | Module WASM modifiable exécuté par le service metaverse, puis connexion à level06 confirmée. Voir level05/resources/solution.md. |
| level06 | Résolu | Motif Perl modifiable dans la configuration de Raven; confirmé par la connexion à level07. Voir level06/resources/solution.md. |
| level07 | Résolu | Évasion du Python jail par introspection d’objets; confirmé par la connexion à level08. Voir level07/resources/solution.md. |
| level08 | Résolu | Requête au socket Black Sun; le contrôle d’état autorise ADMIN après HELLO. Confirmé par la connexion à level09. Voir level08/resources/solution.md. |
| level09 | Résolu | Chaîne `Iheartpwnage` trouvée dans les chaînes du binaire da5id et acceptée comme token; confirmé par la connexion à level10. Voir level09/resources/solution.md. |
| level10 | Résolu | Module WASM modifiable → validation QuickJS → injection via `std.popen`; confirmé par le flag lu par le lanceur setuid. Voir level10/resources/solution.md. |
