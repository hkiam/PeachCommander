---
title: La fenêtre principale
slug: interface-overview
section: Premiers pas
order: 12
related: [navigating, panels-and-tabs]
---

Peach Commander affiche deux listes de fichiers côte à côte afin que vous puissiez voir en même temps d'où viennent les fichiers et où ils vont. L'essentiel de votre travail se déroule dans ces deux panneaux ; les barres qui les entourent vous permettent de changer de disque, d'accéder à un dossier et d'exécuter les commandes de fichiers courantes sans quitter le clavier. Cette visite guidée nomme chaque partie de la fenêtre afin que le reste de l'aide soit clair.

![La fenêtre principale de Peach Commander avec ses deux panneaux et les barres environnantes](screenshots/main-window.png)
*(Figure : la fenêtre principale — deux panneaux avec la barre de boutons, la barre de lecteurs et les barres de chemin au-dessus, et la barre des touches de fonction en dessous.)*

## Les deux panneaux et le panneau actif

La fenêtre est divisée en un panneau gauche et un panneau droit, chacun affichant le contenu d'un dossier. Un seul panneau est actif à la fois : il affiche le curseur (une ligne mise en évidence) et sa barre de chemin est dessinée avec un fond coloré. Les commandes telles que copier et déplacer agissent toujours sur le panneau actif et envoient les fichiers vers l'autre.

1. Cliquez n'importe où dans un panneau pour l'activer, ou appuyez sur Tab pour passer de l'un à l'autre.
2. Utilisez les touches fléchées pour déplacer le curseur vers le haut et vers le bas dans le panneau actif.
3. Appuyez sur Enter sur un dossier pour l'ouvrir, ou sur `..` en haut de la liste pour remonter d'un niveau.

## Les barres autour des panneaux

- **Barre de boutons** (en haut) : une rangée de boutons plats pour les commandes fréquentes. Cliquez sur un bouton pour exécuter sa commande ; cliquez avec le bouton droit sur un bouton pour modifier la barre.
- **Barre de lecteurs** : un bouton par disque ou volume disponible, chacun avec son espace libre. Cliquez sur un volume pour y basculer ce panneau ; un clic droit l’éjecte — proposé pour les volumes amovibles et les images disque montées, grisé pour le disque de démarrage et les partages réseau. Des plugins peuvent fournir leurs propres lecteurs — le Task Manager en est un — et ils se comportent comme n’importe quel volume : le panneau y bascule, son bouton reste sélectionné et l’onglet porte le nom du lecteur.
- **Barre de chemin** : affiche le dossier courant sous forme de fil d'Ariane cliquable. Cliquez sur un segment pour accéder directement à ce dossier, ou cliquez sur le chemin pour saisir un emplacement.
- **Barre d'état** (sous chaque liste) : un récapitulatif en direct du panneau — combien de fichiers et de dossiers sont sélectionnés et leur taille totale.
- **Ligne de commande** (en bas) : un champ de texte où vous pouvez saisir une commande de type shell qui s'exécute dans le dossier courant.
- **Barre des touches de fonction** (tout en bas) : six boutons intitulés F3 Afficher, F4 Modifier, F5 Copier, F6 Déplacer, F7 NouveauDossier et F8 Supprimer. Cliquez sur un bouton ou appuyez sur la touche correspondante.

![Gros plan sur la barre de lecteurs montrant les boutons de volumes et l'espace libre](screenshots/drive-bar-crop.png)
*(Figure : la barre de lecteurs — un bouton par volume, avec l’espace libre restant ; un clic droit sur un volume l’éjecte.)*

## Raccourcis

| Action | Raccourci |
|---|---|
| Changer de panneau actif | Tab |
| Ouvrir le dossier / l'élément sous le curseur | Enter |
| Remonter d'un dossier | Backspace |
| Afficher un fichier | F3 |
| Modifier un fichier | F4 |
| Copier vers l'autre panneau | F5 |
| Déplacer / renommer vers l'autre panneau | F6 |
| Nouveau dossier | F7 |
| Supprimer (vers la Corbeille) | F8 |

## Remarques

- La barre des touches de fonction se réétiquette en direct lorsque vous maintenez une touche de modification enfoncée. Maintenir Shift, par exemple, transforme F6 en une action de renommage sur place, de sorte que les boutons indiquent toujours ce que les touches feront à l'instant présent.
- Presque toutes les barres peuvent être affichées ou masquées. Regardez dans les menus Affichage et Configuration pour activer ou désactiver la barre de boutons, la barre de lecteurs, la ligne de commande ou la barre des touches de fonction, ou pour empiler les deux panneaux l'un au-dessus de l'autre plutôt que côte à côte.
- Sur de nombreux claviers Mac, les touches F agissent par défaut comme des commandes multimédia et de luminosité. Maintenez la touche Fn en même temps que F3-F8, ou activez « Utiliser les touches F1, F2, etc. comme touches de fonction standard » dans Réglages Système, pour les utiliser directement.
