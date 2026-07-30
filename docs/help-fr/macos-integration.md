---
title: Intégration macOS
slug: macos-integration
section: macOS et confidentialité
order: 130
related: [opening-files, privacy-and-security]
---

Peach Commander fonctionne comme le reste de votre Mac. Les applications que vous utilisez, les étiquettes Finder sur lesquelles vous comptez, la feuille de partage, Coup d'œil et même les balayages du trackpad se comportent ici exactement comme dans le Finder — vous avez donc rarement besoin de quitter l'application pour accomplir quelque chose.

## Ouvrir les fichiers avec n'importe quelle application

Cliquez droit sur un fichier (ou une sélection) pour atteindre les actions système qui lui correspondent :

1. Choisissez **Ouvrir** pour ouvrir l'élément comme le ferait Entrée.
2. Choisissez **Ouvrir dans l'application par défaut** pour le confier à l'application que macOS utilise normalement pour ce type.
3. Pointez sur **Ouvrir avec** pour choisir parmi toutes les applications capables d'ouvrir le fichier. Chaque application est listée avec son nom et son icône.
4. En bas de **Ouvrir avec**, choisissez **Autre…** pour parcourir vous-même vers n'importe quelle application.

## Révéler, partager et prévisualiser

- **Révéler dans le Finder** ouvre une fenêtre Finder avec l'élément sélectionné — pratique quand vous avez besoin des propres commandes du Finder.
- **Partager…** ouvre la feuille de partage standard de macOS pour les fichiers sélectionnés (Mail, Messages, AirDrop et tout ce que vous avez activé dans les Réglages Système).
- **Coup d'œil** affiche un aperçu en taille réelle sans ouvrir d'application. Appuyez sur Cmd+Y, ou choisissez-le dans le menu Affichage ou le menu du clic droit.

## Étiquettes Finder

Cliquez droit sur un fichier et pointez sur **Étiquettes** pour basculer les sept étiquettes couleur standard du Finder (Rouge, Orange, Jaune, Vert, Bleu, Violet, Gris). Une coche indique les étiquettes déjà appliquées. Les étiquettes définies ici sont les mêmes étiquettes Finder que vous voyez partout ailleurs sur votre Mac.

## Ouvrir un terminal ici

Choisissez **Fichier ▸ Ouvrir le Terminal ici** (ou **Commandes ▸ Ouvrir le Terminal ici**), ou appuyez sur Cmd+Option+T, pour ouvrir Terminal déjà pointé sur le dossier du panneau actif.

## Services et trackpad

- Le menu **Services** standard de macOS fonctionne sur la sélection courante, de sorte que tout Service acceptant des fichiers est disponible.
- Sur un trackpad, un balayage horizontal à deux doigts parcourt l'historique du panneau comme un navigateur web : balayez à droite pour aller **Précédent**, balayez à gauche pour aller **Suivant**.

## Raccourcis

| Action | Raccourci |
| --- | --- |
| Coup d'œil | Cmd+Y |
| Ouvrir le Terminal ici | Cmd+Option+T |

## Remarques

- Le geste de balayage du trackpad ne se déclenche que lorsque le geste système **Balayer entre les pages** du trackpad est activé dans les Réglages Système.
- Ouvrir le Terminal ici lance Terminal ; il n'est pas disponible pendant que vous parcourez l'intérieur d'une archive.
- Les étiquettes, Révéler dans le Finder, Partager et Ouvrir avec s'appliquent aux vrais fichiers sur le disque, ils ne sont donc pas proposés pour les éléments à l'intérieur des archives ou sur la ligne du dossier parent (..).
- Certaines fonctionnalités de macOS nécessitent une autorisation avant que Peach Commander puisse lire chaque dossier. Si des fichiers semblent manquer, consultez **Confidentialité et sécurité** pour le guide d'accès complet au disque (Commandes ▸ Accès complet au disque…).
