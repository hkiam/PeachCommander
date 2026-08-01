---
title: Afficher des fichiers
slug: viewing-files
section: Affichage et édition
order: 70
related: [editing-files, searching]
---

Peach Commander dispose d'un lecteur intégré qui vous permet de regarder à l'intérieur d'un fichier sans ouvrir une autre application ni modifier le fichier. Appuyez sur F3 sur l'élément sous le curseur et le lecteur s'ouvre instantanément, même pour de très gros fichiers. Il choisit automatiquement la meilleure façon d'afficher le contenu : texte lisible, code coloré, vidage hexadécimal brut, ou image en taille réelle. Vous pouvez aussi prévisualiser un fichier directement dans la fenêtre avec l'Aperçu rapide, ou le confier à Coup d'œil de macOS.

## Afficher un fichier

1. Placez le curseur sur un fichier dans le panneau actif.
2. Appuyez sur F3 (ou choisissez Afficher dans le menu Fichier). Le lecteur s'ouvre dans sa propre fenêtre.
3. Utilisez la barre d'outils pour changer la façon dont le contenu est affiché : Texte, Code, Hexa, Image ou Rendu. Laissez-la sur le réglage automatique pour laisser Peach Commander décider.
4. Faites défiler avec les flèches, Page préc./Page suiv. et la barre de défilement. Pour un long texte, activez le bouton minicarte pour voir et parcourir tout le fichier d'un coup d'œil.
5. Appuyez sur N pour sauter au fichier sélectionné suivant, ou fermez la fenêtre avec Échap.

![Le lecteur intégré affichant un fichier texte avec la minicarte à droite](screenshots/lister-text.png)
*(Figure : affichage d'un fichier texte, avec le sélecteur de représentation et la minicarte dans la barre d'outils.)*

## Rechercher du texte et changer l'encodage

- Appuyez sur Ctrl+F pour rechercher dans le fichier. Appuyez sur F3 pour sauter à la correspondance suivante et Maj+F3 pour la précédente.
- Si le texte semble déformé, cliquez sur Encodage dans la barre d'outils (ou appuyez sur E) pour faire défiler les encodages jusqu'à ce qu'il se lise correctement ; le réglage automatique est généralement juste.
- Appuyez sur W pour basculer le retour à la ligne pour les lignes longues.

## Aperçu rapide et Coup d'œil

L'Aperçu rapide affiche un aperçu en direct dans le panneau que vous n'utilisez *pas*, de sorte que vous pouvez continuer à naviguer d'un côté tout en prévisualisant de l'autre.

1. Appuyez sur Ctrl+Q. Le panneau inactif devient une zone d'aperçu.
2. Déplacez le curseur sur différents fichiers dans le panneau actif pour prévisualiser chacun.
3. Appuyez de nouveau sur Ctrl+Q, ou sur Échap, pour rendre au panneau une liste de fichiers normale.

Pour un aperçu plein écran rapide géré par macOS lui-même, appuyez sur Cmd+Y (Coup d'œil). Appuyez de nouveau sur Cmd+Y ou Espace pour le fermer.

## Raccourcis

| Action | Raccourci |
| --- | --- |
| Afficher le fichier sous le curseur | F3 |
| Afficher seulement le fichier sous le curseur (ignorer les fichiers marqués) | Maj+F3 |
| Ouvrir dans un lecteur externe | Option+F3 |
| Rechercher dans le lecteur | Ctrl+F |
| Correspondance suivante / précédente | F3 / Maj+F3 |
| Aperçu rapide dans l'autre panneau | Ctrl+Q |
| Coup d'œil (aperçu macOS) | Cmd+Y |
| Fermer le lecteur ou l'Aperçu rapide | Échap |

## La page Infos du panneau latéral

Le panneau latéral (**Présentation > Panneau d’aperçu**, ou Cmd+Maj+P) comporte une page **Infos** qui présente l’élément sous le curseur comme le fait la barre latérale d’informations du Finder.

- L’aperçu occupe toute la largeur du panneau : élargissez le panneau et l’aperçu grandit avec lui.
- C’est un véritable aperçu macOS, pas une petite vignette : tous les formats que Coup d’œil sait afficher fonctionnent ici, et un document de plusieurs pages se parcourt page par page dans l’aperçu.
- En dessous figurent le nom, le type et la taille, puis les dates de création et de modification et le dossier où se trouve l’élément.

Lorsque le curseur se déplace, le nom et les informations se mettent à jour immédiatement ; l’aperçu suit un instant plus tard, afin qu’une flèche maintenue à travers un long dossier ne lance pas un aperçu pour chaque ligne traversée.

## Remarques

- Le lecteur est en lecture seule. Pour modifier un fichier, utilisez plutôt l'éditeur (voir Modifier des fichiers).
- Les très gros fichiers s'ouvrent sans délai : le texte ouvre une vue rapide et défilable, et la vue hexa est diffusée directement depuis le disque quelle que soit la taille.
- Appuyez sur F3 sur un dossier pour voir un résumé de son contenu et sa taille totale au lieu des octets d'un fichier.
- Le mode Rendu affiche du contenu formaté tel que des pages web ; le mode hexa montre les octets bruts côte à côte avec leurs caractères, ce qui est pratique pour inspecter des fichiers binaires.
