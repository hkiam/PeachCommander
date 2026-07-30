---
title: La barre de boutons
slug: toolbar
section: Personnalisation
order: 110
related: [keyboard-shortcuts, settings]
---

La barre de boutons est la bande de boutons à icônes en haut de la fenêtre. Chaque bouton est un raccourci en un clic que vous définissez vous-même : exécuter une commande intégrée, lancer un programme ou une application externe, sauter à un dossier, ou ouvrir toute une sous-barre de boutons supplémentaires. C'est le moyen le plus rapide de mettre à portée les actions que vous utilisez le plus, et vous pouvez l'adapter exactement à votre façon de travailler.

## Personnaliser la barre de boutons

1. Choisissez **Configuration > Personnaliser la barre d'outils…**, ou cliquez droit sur la barre et choisissez **Modifier la barre de boutons…**.
2. La liste de gauche montre les boutons actuels. Utilisez **+** pour ajouter un bouton, **—** pour ajouter un séparateur, **−** pour retirer le bouton sélectionné, et **↑ / ↓** pour réordonner.
3. Sélectionnez un bouton et remplissez le formulaire de droite :
   - **Commande** — saisissez une commande intégrée, ou cliquez sur **Choisir…** pour en sélectionner une dans une liste. Vous pouvez aussi saisir le chemin d'un programme ou d'une application, un dossier à ouvrir, ou une autre barre de boutons à utiliser comme sous-barre.
   - **Légende** — l'étiquette et l'infobulle affichées pour le bouton.
   - **Paramètres** et **Chemin de départ** — passés aux programmes externes. Les caractères de remplacement tels que `%P` (dossier source), `%N` (fichier courant) et `%S` (fichiers sélectionnés) sont remplis à l'exécution du bouton.
   - **Icône** — choisissez un symbole SF ou utilisez l'icône d'un fichier ou d'une application ; activez **icône seule** pour masquer la légende.
4. Cliquez sur **Enregistrer**. La bande se recharge immédiatement.

![La barre de boutons en haut de la fenêtre avec des boutons à icônes](screenshots/button-bar-crop.png)
*(Figure : la barre de boutons se trouve au-dessus des panneaux de fichiers ; chaque bouton exécute une commande, un programme, un dossier ou une sous-barre.)*

## Sous-barres et débordement

Un bouton peut ouvrir une *sous-barre* — un second jeu de boutons superposé au premier. Cliquez dessus pour descendre ; un bouton **◀** à gauche vous ramène à la barre précédente. Quand il y a plus de boutons que la largeur de la fenêtre ne peut en contenir, les surnuméraires se replient derrière un chevron **»** à l'extrémité droite ; cliquez dessus pour les atteindre.

## Déposer des fichiers sur un bouton

Vous pouvez glisser des fichiers ou des dossiers directement sur un bouton :

- **Bouton de dossier** — les éléments déposés sont copiés dans ce dossier en arrière-plan.
- **Bouton de programme** — le programme s'exécute avec les éléments déposés comme sélection.
- **Bouton de commande** — la commande s'exécute normalement.

## Barre de boutons verticale

Pour déplacer la bande du haut de la fenêtre vers une colonne le long du côté gauche, choisissez **Affichage > Barre de boutons verticale**. Choisissez-la à nouveau pour revenir à la bande horizontale.

## Remarques

- La barre est stockée dans un fichier de barre de boutons standard compatible avec Total Commander, de sorte que les barres que vous avez déjà peuvent être réutilisées.
- Aucun raccourci clavier n'est assigné à ces actions par défaut, mais vous pouvez ajouter les vôtres — voir [Raccourcis clavier](keyboard-shortcuts).
- Un bouton sans icône et sans commande s'affiche comme un simple séparateur, pratique pour regrouper des boutons liés.
