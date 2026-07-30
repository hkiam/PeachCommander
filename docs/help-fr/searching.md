---
title: Rechercher des fichiers
slug: searching
section: Rechercher des fichiers
order: 60
related: [selecting-files, quick-search-and-filter]
---

Lorsque vous devez retrouver des fichiers n'importe où sur votre Mac — par nom, par ce qu'ils contiennent, ou par taille et date —, utilisez la fenêtre Rechercher des fichiers. Elle explore un ou plusieurs dossiers (et leurs sous-dossiers), peut regarder à l'intérieur des fichiers texte et des archives, et vous permet d'envoyer directement tout ce qu'elle trouve dans un panneau, afin que vous puissiez agir sur les résultats comme s'il s'agissait d'un dossier ordinaire.

## Rechercher des fichiers par nom

1. Dans le panneau affichant le dossier que vous souhaitez explorer, choisissez **Commandes > Rechercher des fichiers…** (ou appuyez sur Cmd+Shift+F).
2. Dans l'onglet **Général**, saisissez un motif de nom dans **Rechercher**. Vous pouvez utiliser des caractères génériques tels que `*.pdf` ou `report_*.docx`. Pour explorer plusieurs dossiers à la fois, indiquez-les dans le champ du dossier de départ, séparés par un point-virgule (`;`).
3. Cliquez sur **Démarrer**. Les correspondances apparaissent dans la liste de résultats ci-dessous au fur et à mesure qu'elles sont trouvées.
4. Double-cliquez sur un résultat pour accéder à ce fichier dans le panneau actif, ou sélectionnez un résultat et cliquez sur **Afficher** (F3) pour l'ouvrir dans le visualiseur intégré.

![La fenêtre Rechercher des fichiers sur l'onglet Général, affichant le motif de nom, le dossier et la liste de résultats](screenshots/find-files-general.png)
*(Figure : l'onglet Général — rechercher par motif de nom dans un ou plusieurs dossiers.)*

## Rechercher par contenu, taille et date

1. Pour rechercher à l'intérieur des fichiers, sélectionnez **Rechercher un texte** dans l'onglet Général et saisissez le texte à trouver. Des options vous permettent de le rendre **Sensible à la casse**, de ne faire correspondre qu'un **Mot entier**, de traiter le texte comme une **Expression régulière**, d'effectuer une **Recherche de contenu hexadécimal**, ou de trouver les fichiers **Ne contenant pas** le texte.
2. Passez à l'onglet **Avancé** pour restreindre les résultats par **Taille** (par exemple de `10K` à `5M`), par plage de **date de modification**, ou aux fichiers modifiés au cours des N derniers jours.
3. Activez **Rechercher dans les archives** pour regarder à l'intérieur des archives de la famille zip (zip, jar, war et similaires).
4. Pour limiter la recherche à ce que vous avez déjà choisi, activez **Rechercher uniquement dans les éléments sélectionnés** avant de démarrer.

![La fenêtre Rechercher des fichiers sur l'onglet Avancé, affichant les filtres de taille et de date](screenshots/find-files-advanced.png)
*(Figure : l'onglet Avancé — filtrer par taille, date et autres attributs.)*

Si vous avez des extensions qui ajoutent des champs de contenu (comme les dimensions d'une image), l'onglet **Extensions** vous permet d'exiger qu'un champ satisfasse une condition — par exemple, uniquement les images de plus de 1000 pixels de large.

![La fenêtre Rechercher des fichiers sur l'onglet Extensions, affichant une condition de champ de contenu](screenshots/find-files-plugins.png)
*(Figure : l'onglet Extensions — faire correspondre sur des champs de contenu fournis par une extension.)*

## Recherches rapides avec Spotlight

Pour les dossiers locaux que macOS a déjà indexés, activez **Utiliser Spotlight** dans l'onglet Général pour des résultats quasi instantanés. Spotlight interroge l'index au lieu de parcourir les fichiers : il ignore donc les expressions régulières, les limites de profondeur des sous-dossiers et la portée « sélection uniquement ».

## Réutiliser et transmettre vos résultats

- **Envoyer dans la liste** place chaque résultat dans le panneau actif sous forme de liste temporaire, afin que vous puissiez copier, déplacer ou supprimer l'ensemble d'un coup.
- Dans l'onglet **Charger / Enregistrer**, choisissez **Enregistrer comme modèle…** pour conserver la recherche actuelle (motifs et options) et la reprendre plus tard dans la liste des modèles.

## Raccourcis

| Action | Raccourci |
| --- | --- |
| Ouvrir Rechercher des fichiers | Cmd+Shift+F ou Option+F7 |
| Démarrer / arrêter la recherche | Bouton Démarrer dans la fenêtre |
| Afficher le résultat sélectionné | F3 |

## Remarques

- La recherche de contenu lit les fichiers entiers pour les dossiers locaux ; sur les autres emplacements, les fichiers très volumineux sont ignorés (environ 16 Mo, ou 64 Mo avec une expression régulière).
- La recherche à l'intérieur des archives descend jusqu'à quatre niveaux d'archives imbriquées.
- **Inclure les dossiers dans les résultats** répertorie aussi les dossiers dont le nom correspond, pas seulement les fichiers.
- Spotlight ne couvre que les dossiers locaux indexés ; pour les emplacements réseau ou la correspondance par motif, laissez-le désactivé et laissez Rechercher des fichiers parcourir.
