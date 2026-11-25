# Snow Crash — suivi

Cible autorisée : la VM Snow Crash de 42. Les solutions décrivent les méthodes de résolution des niveaux 00 à 09. Les fichiers `flag` contiennent les valeurs de référence ; les résultats et les changements de compte restent à valider sur la VM.

La progression peut s’effectuer dans une session SSH ouverte avec `level00`, puis en changeant de compte avec `su - levelNN` et le flag précédent. Chaque solution précise son compte de départ.

| Niveau | État | Solution |
| --- | --- | --- |
| level00 | À valider sur la VM | Secret extrait de la section ELF `.flag_data`. [Solution](level00/resources/solution.md). |
| level01 | À valider sur la VM | Secret exposé dans la ligne de commande du service Gargoyle. [Solution](level01/resources/solution.md). |
| level02 | À valider sur la VM | Secret laissé dans un fichier temporaire lisible par tous. [Solution](level02/resources/solution.md). |
| level03 | À valider sur la VM | Script CMake chargé par le service Burbclave. [Solution](level03/resources/solution.md). |
| level04 | À valider sur la VM | Macro M4 exécutée par le service Babel. [Solution](level04/resources/solution.md). |
| level05 | À valider sur la VM | Module WASM modifiable exécuté par le service Metaverse. [Solution](level05/resources/solution.md). |
| level06 | À valider sur la VM | Motif Perl modifiable dans la configuration de Raven. [Solution](level06/resources/solution.md). |
| level07 | À valider sur la VM | Évasion du jail Python par introspection d’objets. [Solution](level07/resources/solution.md). |
| level08 | À valider sur la VM | Requête au socket Black Sun : le contrôle d’état autorise `ADMIN` après `HELLO`. [Solution](level08/resources/solution.md). |
| level09 | À valider sur la VM | Chaîne `Iheartpwnage` extraite du binaire Da5id et acceptée comme token. [Solution](level09/resources/solution.md). |
| level10 | Non documenté dans cette archive | Aucun dossier ni fichier de solution fourni. |
