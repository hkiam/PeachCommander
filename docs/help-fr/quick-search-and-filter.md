---
title: Recherche rapide et filtre
slug: quick-search-and-filter
section: Organiser l'affichage
order: 44
related: [searching, view-modes-and-sorting]
---

Lorsqu'un dossier contient des centaines d'éléments, vous n'avez que rarement besoin de faire défiler. Peach Commander vous permet d'accéder directement à un fichier en saisissant son nom (recherche rapide), de réduire la liste aux seuls éléments qui vous intéressent (filtre rapide), et d'afficher ou de masquer les fichiers cachés que macOS garde normalement hors de vue. Les trois fonctionnent dans le panneau actif sans ouvrir de boîte de dialogue.

## Accéder à un fichier en le saisissant (recherche rapide)

1. Cliquez sur un panneau de fichiers pour l'activer.
2. Commencez à saisir le début d'un nom. Le curseur saute au premier élément correspondant.
3. Continuez à saisir pour affiner la correspondance, ou appuyez de nouveau sur la même lettre pour parcourir les éléments qui commencent par cette lettre.
4. Ce que vous avez saisi apparaît au-dessus du panneau, avec le rang de la correspondance et leur nombre — par exemple `⌕ re  2/3`. Il devient rouge quand rien ne correspond.
5. Appuyez sur Retour arrière pour reprendre la dernière lettre, ou sur Esc pour terminer la recherche. Retour arrière ne modifie que la recherche en cours ; le reste du temps, il remonte toujours au dossier parent.
6. Le texte saisi s'efface après une courte pause, ce qui vous permet de lancer une nouvelle recherche à tout moment.

Par défaut, les lettres simples vont dans la ligne de commande et la recherche rapide se déclenche avec Ctrl+Option+lettre (le comportement classique). Vous pouvez faire réagir la recherche rapide à la saisie simple, ou la désactiver, dans les réglages de Configuration.

## Filtrer la liste (filtre rapide)

1. Dans le panneau actif, appuyez sur Ctrl+S pour activer le filtre rapide.
2. Saisissez un masque de filtre. Le panneau se réduit en direct aux éléments correspondants au fur et à mesure que vous saisissez.
3. Appuyez sur Esc pour effacer le filtre et afficher de nouveau tout.

Le filtre accepte plusieurs sortes de masques :

- **Le texte simple** correspond à tout nom qui contient ce que vous avez saisi (par exemple, `report` affiche tout élément comportant « report » n'importe où dans son nom).
- **Les caractères génériques** utilisent `*` (n'importe quels caractères) et `?` (un caractère). Séparez plusieurs masques par un point-virgule et ajoutez les exclusions après une barre verticale, par exemple `*.jpg;*.png|*thumb*` pour afficher les images mais masquer les vignettes.
- **Les étiquettes du Finder** filtrent par couleur d'étiquette : saisissez `tag:red` (ou `#red`) pour n'afficher que les éléments étiquetés en rouge, ou un simple `tag:` pour afficher tout ce qui porte une étiquette.

## Afficher les fichiers cachés

Appuyez sur Ctrl+H, ou choisissez la commande dans le menu Affichage, pour basculer l'affichage des éléments cachés (noms commençant par un point et fichiers cachés par le système). Le réglage s'applique au panneau actif et est mémorisé d'une session à l'autre.

## Raccourcis

| Action | Raccourci |
| --- | --- |
| Recherche rapide (mode classique) | Ctrl+Option+lettre |
| Activer/désactiver le filtre rapide | Ctrl+S |
| Effacer le filtre / annuler | Esc |
| Afficher/masquer les fichiers cachés | Ctrl+H |

## Remarques

- La recherche rapide ne fait que déplacer le curseur ; le filtre rapide, lui, change réellement quels éléments sont listés. Utilisez le filtre lorsque vous voulez travailler sur un sous-ensemble (par exemple, sélectionner ou copier uniquement les correspondances).
- Les réglages du filtre et des fichiers cachés sont propres à chaque panneau, de sorte que les deux côtés peuvent afficher des choses différentes en même temps.
- La recherche rapide fait correspondre les noms depuis le début ; le mode texte simple du filtre fait correspondre n'importe où dans le nom. Utilisez un caractère générique comme `*text*` si vous voulez que le filtre se comporte de la même manière.
