---
title: Apparence
slug: appearance
section: Personnalisation
order: 114
related: [settings]
---

Peach Commander peut s'accorder à l'apparence du reste de votre Mac ou adopter un style qui lui est propre. Vous pouvez suivre le réglage clair ou sombre du système (ou en forcer un), recolorer les panneaux de fichiers, mettre en évidence les fichiers par type et ajuster la taille de police de la liste et le format de date pour que les panneaux se lisent exactement comme vous l'aimez.

## Choisir un thème de couleurs

Un thème remplace toute la palette des panneaux en une seule fois.

1. Ouvrez la fenêtre des réglages en choisissant Configuration > Options…, ou appuyez sur Cmd+,.
2. Sélectionnez la page **Couleurs**.
3. Dans le menu **Thème**, choisissez :
   - **Système (par défaut)** — aucun thème. Les panneaux suivent le réglage Apparence ci-dessous, exactement comme auparavant. C’est le réglage par défaut.
   - **Clair** / **Sombre** — fixer la palette claire ou sombre intégrée, quel que soit le réglage de macOS.
   - **Minuit** — un thème sombre qui n’est pas seulement gris : des panneaux indigo profond, un texte gris-bleu doux, une ligne de curseur blanche et de l’ambre pour les fichiers marqués.
   - **Norton Commander** — l’aspect bleu et cyan du gestionnaire de fichiers DOS d’origine, dans ses véritables couleurs CGA : panneaux bleus, texte cyan, ligne du curseur cyan clair et jaune pour les fichiers marqués.

Un thème apporte sa propre base claire/sombre, afin que les feuilles, les barres de défilement et les contrôles standard s’y accordent — c’est pourquoi le menu **Apparence** est grisé tant qu’un thème est sélectionné. Les couleurs personnalisées des panneaux (ci-dessous) restent prioritaires sur le thème.

![Peach Commander dans la palette Norton Commander](screenshots/theme-norton.png)
*(Figure: la palette Norton Commander — le bleu, le cyan et le jaune CGA d’origine.)*

Le thème Norton Commander utilise les valeurs CGA authentiques de l’original de 1986 : `#0000AA` bleu, `#00AAAA` cyan, `#55FFFF` pour la ligne du curseur, `#FFFF55` pour les fichiers marqués. La barre du curseur s’inverse en texte sombre sur cyan, comme le dessinait l’original, tandis que les fichiers marqués conservent leur jaune.

![Gros plan sur la ligne du curseur dans la palette Norton](screenshots/theme-norton-cursor-crop.png)
*(Figure: la barre du curseur s’inverse ; les fichiers marqués restent jaunes.)*

![La page de réglages Couleurs dans la palette Norton Commander](screenshots/theme-norton-settings.png)
*(Figure: les fenêtres de l’application suivent également le thème.)*

Les thèmes ne concernent que les couleurs. La disposition des panneaux, les cadres et les polices restent inchangés — Norton Commander ne ramène ni les bordures à double trait ni la police matricielle DOS.

## Écrire votre propre thème

Les thèmes sont de simples fichiers texte, un par thème, dans un dossier `themes` à l’intérieur de votre dossier de configuration.

1. Sur la page **Couleurs**, cliquez sur **Dossier des thèmes…**. Le dossier est créé s’il n’existe pas, et la première fois qu’il est vide, Peach Commander y dépose un fichier commenté `example-norton.ini` qui liste toutes les couleurs modifiables.
2. Copiez ce fichier, donnez-lui un nouveau nom et modifiez-le. Le nom du fichier (sans `.ini`) est l’identifiant du thème ; la ligne `Name` est ce qu’affiche le menu Thème.
3. Enregistrez. Rouvrez le menu **Thème** — votre thème figure dans la liste. Aucun redémarrage nécessaire.

Un thème minimal tient en trois lignes :

```ini
[Theme]
Name = My Midnight
Base = dark

[Colors]
ListBackground = #101020
ListText       = #C0C0D0
```

![Peach Commander dans un thème écrit par l’utilisateur](screenshots/theme-custom.png)
*(Figure: un thème chargé depuis un fichier du dossier des thèmes.)*

`Base` choisit la palette intégrée (`light` ou `dark`) qui fournit toutes les couleurs que vous n’indiquez pas ; vous n’écrivez donc que ce que vous voulez changer. Les couleurs s’écrivent `#RRGGBB`. Les lignes commençant par `;` ou `#` sont des commentaires.

Si quelque chose est incorrect dans le fichier, Peach Commander ignore cette seule ligne et conserve le reste de votre thème — il ne rejette pas le fichier. La raison est écrite dans le journal système, visible dans Console.app en filtrant sur `[theme]`.

Les noms `light`, `dark`, `norton` et `system` appartiennent aux thèmes intégrés ; un fichier portant l’un de ces noms est ignoré afin de ne pas masquer un thème livré avec l’application. Si vous supprimez le fichier du thème sélectionné, Peach Commander revient à **Système (par défaut)**.
## Définir l'apparence claire, sombre ou système

1. Ouvrez la fenêtre des réglages en choisissant Configuration > Options…, ou appuyez sur Cmd+,.
2. Sélectionnez la page **Couleurs**.
3. Dans le menu **Apparence**, choisissez l'une des options :
   - **Système (suivre macOS)** — s'accorde automatiquement au réglage clair/sombre actuel de votre Mac.
   - **Clair** — toujours utiliser la palette claire.
   - **Sombre** — toujours utiliser la palette sombre.

![La page de réglages Couleurs montrant le menu Apparence et les puits de couleur personnalisés des panneaux](screenshots/settings-colors.png)
*(Figure : la page Couleurs : choisissez une apparence et remplacez les couleurs individuelles des panneaux.)*

## Personnaliser les couleurs des panneaux

Sur la même page **Couleurs**, sous **Couleurs personnalisées des panneaux**, cochez la case à côté d'un élément et choisissez une couleur dans le puits à côté :

- **Texte** — les noms de fichiers et de dossiers.
- **Arrière-plan** — l'arrière-plan du panneau.
- **Texte sélectionné** — la couleur utilisée pour les fichiers marqués.
- **Cadre du curseur** — le contour autour de l'élément courant.

Laissez une case décochée pour conserver la couleur intégrée de cet élément. Cliquez sur **Réinitialiser aux valeurs par défaut** pour effacer tous les remplacements d'un coup.

## Colorer les fichiers par type

1. Ouvrez Configuration > Options… et sélectionnez la page **Affichage**.
2. Cliquez sur **Couleurs par type de fichier…**.
3. Ajoutez une règle avec un masque de nom tel que `*.zip` ou `*.txt`, puis choisissez une couleur pour les fichiers correspondants.
4. Utilisez **Ajouter une règle** pour d'autres masques ; cliquez sur **Terminé** pour enregistrer ou **Annuler** pour abandonner.

Les fichiers correspondants apparaissent alors dans la couleur choisie dans les deux panneaux.

## Ajuster la taille de police et le format de date

Sur la page **Affichage**, vous pouvez aussi :

- Choisir la **taille de police** de la liste des panneaux en points.
- Saisir un motif de **format de date** pour contrôler l'affichage des dates de modification ; laissez-le vide pour utiliser le format régional de votre Mac. Un aperçu en direct apparaît sous le champ à mesure que vous saisissez.
- Activer **Fond de rangée alterné** pour un rayage type zébrure qui facilite la lecture des longues listes.

## Raccourcis

| Action | Raccourci |
| --- | --- |
| Ouvrir les réglages | Cmd+, |

## Remarques

- Le menu Apparence n’agit que tant que le thème est **Système (par défaut)** ; un thème définit sa propre base.
- Un thème colore aussi les fenêtres de l’application. Les fenêtres du système — Ouvrir, Enregistrer, les sélecteurs de couleur et de police, et les alertes — conservent leur aspect standard, tout comme les fenêtres ouvertes par les modules.
- Le réglage d'apparence stylise les panneaux de fichiers. Les dialogues système, les alertes et les contrôles standard suivent toujours macOS.
- Le lecteur de fichiers intégré utilise des palettes de coloration syntaxique claires et sombres assorties, pour que le code coloré reste lisible dans les deux apparences.
- Les couleurs personnalisées et les règles par type de fichier sont enregistrées avec vos réglages et réappliquées chaque fois que vous ouvrez l'application.
