---
title: Ouvrir des fichiers et des dossiers
slug: opening-files
section: Fichiers et dossiers
order: 20
related: [viewing-files, selecting-files]
---

Peach Commander ouvre les fichiers et les dossiers directement depuis l'un ou l'autre panneau, en utilisant les mêmes applications et fonctionnalités système sur lesquelles vous comptez déjà dans le Finder. Appuyez sur une touche pour ouvrir l'élément sous le curseur dans son application par défaut, ou cliquez avec le bouton droit pour accéder à un menu complet d'actions — ouvrir avec une autre application, afficher l'élément dans le Finder, le partager, ou ouvrir une fenêtre Terminal là où vous vous trouvez.

## Ouvrir un élément

1. Cliquez sur un fichier ou un dossier dans un panneau pour y placer le curseur (la ligne mise en évidence).
2. Appuyez sur Enter (ou double-cliquez).
   - Un dossier s'ouvre dans le même panneau.
   - Un fichier s'ouvre dans son application macOS par défaut — la même que celle que le Finder utiliserait.
   - Une archive (comme un .zip) s'ouvre comme un dossier afin que vous puissiez en parcourir le contenu.

![La fenêtre principale de Peach Commander avec les deux panneaux affichant des fichiers et des dossiers](screenshots/main-window.png)
*(Figure : placez le curseur sur un élément, puis appuyez sur Enter pour l'ouvrir.)*

## Ouvrir avec une autre application, afficher ou partager

Cliquez avec le bouton droit sur un fichier (ou appuyez sur Shift+F10) pour ouvrir le menu de l'élément, puis choisissez :

- **Ouvrir** ou **Ouvrir dans l'application par défaut** — ouvre le fichier comme le ferait Enter.
- **Ouvrir avec** — choisissez n'importe quelle application installée capable d'ouvrir ce fichier, ou choisissez **Autre…** pour en rechercher une.
- **Quick Look** — prévisualisez le fichier sans ouvrir d'application.
- **Afficher dans le Finder** — montre le fichier sélectionné dans une fenêtre du Finder.
- **Partager…** — envoie le fichier via la feuille de partage de macOS.

Le menu fusionne aussi les **Services** macOS standards pour le fichier sélectionné, et ajoute des **Étiquettes** afin que vous puissiez appliquer les étiquettes de couleur habituelles du Finder.

## Ouvrir un Terminal dans le dossier courant

Choisissez **Ouvrir le Terminal ici** dans le menu Fichier ou Commandes (Cmd+Option+T) pour ouvrir une fenêtre Terminal déjà pointée sur le dossier du panneau actif.

## Raccourcis

| Action | Touche |
|---|---|
| Ouvrir l'élément sous le curseur | Enter |
| Afficher un fichier (visualiseur) | F3 |
| Modifier un fichier | F4 |
| Aperçu Quick Look | Cmd+Y |
| Lire les informations / propriétés | Option+Enter |
| Ouvrir le menu de l'élément | Shift+F10 ou clic droit |
| Ouvrir le Terminal ici | Cmd+Option+T |

## Remarques

- « Application par défaut » désigne l'application que macOS est configuré pour utiliser avec ce type de fichier ; modifiez-la dans la fenêtre Lire les informations du fichier, exactement comme dans le Finder.
- **Afficher dans le Finder**, **Partager…** et **Ouvrir avec ▸ Autre…** s'appliquent aux éléments situés sur le disque de votre Mac. Ils ne sont pas disponibles pour les éléments à l'intérieur d'une archive ou sur une connexion distante (FTP/SFTP).
- Cliquer avec le bouton droit sur un processus en cours d'exécution (dans une vue de processus) affiche un menu plus court, propre au processus, au lieu des actions sur les fichiers.
