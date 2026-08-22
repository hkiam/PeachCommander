---
title: Les fichiers CSV en tableau
slug: csv-lister
section: Extensions
order: 129
related: [plugins, viewing-files, log-viewer]
---

Appuyez sur **F3** sur un fichier `.csv` ou `.tsv` et il s’ouvre comme un vrai tableau — colonnes, en-têtes, tri et filtre — au lieu de lignes de texte contenant des virgules.

C’est une extension : vous pouvez la désactiver ou la supprimer dans **Configuration ▸ Extensions…**. Sans elle, F3 affiche le fichier en texte brut, ce qui reste tout à fait lisible pour un petit fichier.

## Le séparateur est déduit, pas supposé

Virgule, point-virgule, tabulation, barre verticale et deux-points sont tous candidats. L’extension compte chacun d’eux sur les vingt premières lignes et retient celui qui apparaît le même nombre de fois sur le plus de lignes — un fichier dont chaque ligne compte quatre points-virgules est un fichier à points-virgules, quoi qu’en dise son extension. Cela compte en pratique : un `.csv` exporté par un tableur sur un système français est souvent séparé par des points-virgules, et un `.tsv` n’est pas toujours séparé par des tabulations.

La première ligne est traitée comme ligne d’en-tête et devient les titres de colonnes.

## Trier et filtrer

Cliquez sur un en-tête de colonne pour trier dessus, cliquez de nouveau pour inverser. Le tri est **numérique quand les deux valeurs sont des nombres** et alphabétique sinon : une colonne de tailles trie donc 9 avant 10 et non après.

Le champ de recherche filtre à la frappe, sans distinguer majuscules et minuscules. Par défaut il regarde dans toutes les colonnes ; choisissez une colonne dans le menu à côté pour ne chercher que là.

## Ce qu’elle ne fait pas

L’analyseur est volontairement minimal, et une limite mérite d’être connue avant de vous surprendre : **un séparateur à l’intérieur d’un champ entre guillemets reste traité comme un séparateur.** Une ligne comme

```
"Smith, John",42
```

donne trois cellules au lieu de deux. Les guillemets encadrants sont retirés lorsqu’ils entourent un champ entier, mais le guillemetage n’est pas interprété au-delà. Pour un fichier où cela compte, la visionneuse intégrée ou un tableur est l’outil approprié.

Les lignes vides sont ignorées, et un champ qui s’étend sur plusieurs lignes n’est pas pris en charge.
