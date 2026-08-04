---
title: Modes d'affichage et tri
slug: view-modes-and-sorting
section: Organiser l'affichage
order: 42
related: [panels-and-tabs, quick-search-and-filter]
---

Chaque panneau peut afficher son dossier dans la disposition qui convient à la tâche : une liste détaillée avec des colonnes, une liste compacte de noms sur plusieurs colonnes, une grille d'icônes, une galerie de grandes vignettes ou une arborescence de dossiers. Vous pouvez aussi trier la liste par nom, extension, taille ou date, choisir exactement quelles colonnes apparaissent, et activer le tri naturel (numérique) pour que les noms comportant des chiffres s'ordonnent comme vous vous y attendez. Le mode d'affichage, l'ordre de tri et les colonnes se règlent par panneau, si bien que les deux côtés peuvent avoir un aspect complètement différent.

## Changer de mode d'affichage

1. Cliquez sur le panneau que vous souhaitez modifier pour l'activer.
2. Ouvrez le menu Affichage et choisissez un mode : **Complet (Détails)** pour la liste à colonnes, **Bref (Colonnes)** pour une liste dense de noms sur plusieurs colonnes, **Icônes** pour une grille d'icônes, **Vignettes (Galerie)** pour de grands aperçus, ou **Arborescence** pour une arborescence de dossiers.
3. Pour passer rapidement d'un mode à l'autre sans ouvrir le menu, appuyez sur Cmd+Shift+M. Chaque pression passe au mode suivant.

![Un panneau montrant les différents modes d'affichage : détails, bref, icônes et galerie](screenshots/view-modes.png)
*(Figure : le même dossier affiché sous forme de liste détaillée, de liste brève à colonnes, de grille d'icônes et de galerie de vignettes.)*

## Trier la liste de fichiers

1. En vue Détails, cliquez sur un en-tête de colonne (Nom, Ext, Taille ou Date) pour trier selon celui-ci. Une petite flèche dans l'en-tête indique la colonne de tri courante et son sens.
2. Cliquez de nouveau sur le même en-tête pour inverser l'ordre.
3. Vous pouvez aussi choisir Affichage > Trier par et sélectionner Nom, Extension, Taille, Date ou Non trié.

Les dossiers sont toujours regroupés en haut, devant les fichiers, et l'entrée `..` qui vous fait remonter d'un niveau reste épinglée en première position. Le tri par nom ou extension est croissant par défaut (de A à Z) ; le tri par taille ou date affiche par défaut les éléments les plus récents ou les plus volumineux en premier.

## Choisir quelles colonnes apparaissent

1. Choisissez Configuration > Colonnes….
2. Activez ou désactivez des colonnes et définissez leur ordre. Les colonnes disponibles comprennent Nom, Ext, Taille, Date, Attr (attributs), Étiquettes et Commentaire.
3. Appliquez vos modifications. Les colonnes affectent la vue Détails du panneau actif.

![La fenêtre de configuration des colonnes avec la liste des colonnes disponibles](screenshots/columns-config.png)
*(Figure : choisissez quelles colonnes apparaissent dans la vue Détails et définissez leur ordre.)*

## Raccourcis

| Action | Raccourci |
|---|---|
| Faire défiler les modes d'affichage | Cmd+Shift+M |
| Vue Bref (colonnes) | Ctrl+F1 |
| Vue Complet (détails) | Ctrl+F2 |
| Vue Vignettes (galerie) | Ctrl+Shift+F1 |
| Vue Arborescence | Ctrl+F8 |
| Trier par nom | Ctrl+F3 |
| Trier par extension | Ctrl+F4 |
| Trier par taille | Ctrl+F5 |
| Trier par date | Ctrl+F6 |

## Astuces

- Le tri naturel (numérique) est activé par défaut, si bien que `file2` vient avant `file10` plutôt qu'après. Vous pouvez le désactiver dans Configuration > Options, dans les réglages d'affichage.
- Vous pouvez élargir ou rétrécir une colonne en vue Détails en faisant glisser la séparation entre les en-têtes de colonnes.
- Si vous utilisez la navigation clavier de macOS (Réglages Système ▸ Clavier), la rangée Ctrl+F1 à Ctrl+F8 appartient au système — barre des menus, Dock, barre d’outils — et n’atteint jamais Peach Commander. Passez le schéma de touches sur **macOS** dans les réglages : les modes d’affichage sont alors sur Cmd+1, Cmd+2 et Cmd+3, et le tri sur Alt+Cmd+1 à Alt+Cmd+4.
- Le mode d'affichage, l'ordre de tri et le choix des colonnes sont mémorisés par panneau : vous pouvez ainsi garder un côté sous forme de liste détaillée et l'autre sous forme de galerie de photos.
