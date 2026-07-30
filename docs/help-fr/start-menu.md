---
title: Le menu Démarrer et les commandes personnalisées
slug: start-menu
section: Personnalisation
order: 111
related: [toolbar, keyboard-shortcuts]
---

Le menu **Démarrer** est votre propre menu personnel, situé dans la barre de menus à côté de Fichier, Édition et les autres. Il contient des commandes que vous définissez vous-même, de sorte que les actions que vous utilisez le plus souvent sont toujours à un clic. Dans la tradition des gestionnaires de fichiers classiques à deux panneaux, chaque entrée peut exécuter une commande intégrée, lancer un programme ou une application externe, ou sauter directement à un dossier. Peach Commander est livré avec le menu Démarrer vide et prêt à être rempli.

## Comment ajouter vos propres commandes

1. Choisissez **Démarrer > Modifier le menu Démarrer…**. Peach Commander ouvre votre fichier de commandes utilisateur (le créant avec un exemple commenté la première fois).
2. Ajoutez une section par commande. Chaque section commence par un nom entre crochets, puis quelques clés simples :
   - **cmd** — ce qu'il faut exécuter : un chemin de programme, une application, une commande intégrée `cm_`, ou une autre de vos commandes.
   - **param** — paramètres passés à un programme. Les caractères de remplacement sont remplis à l'exécution de la commande : `%P` (dossier source), `%N` (fichier courant), `%T` (dossier de l'autre panneau), `%M` (fichier de l'autre panneau), `%S` (fichiers sélectionnés).
   - **path** — le dossier de démarrage (par défaut, le dossier courant).
   - **menu** — le titre affiché dans le menu Démarrer.
   - **key** — un raccourci facultatif, p. ex. `C+S+B`.
3. Enregistrez le fichier. Le menu Démarrer se met à jour tout seul la prochaine fois que Peach Commander devient actif, de sorte que vos nouvelles entrées apparaissent aussitôt.

## Astuces

- Pour ouvrir le dossier courant dans Terminal, définissez **cmd** sur `open`, **param** sur `-a Terminal %P` et **menu** sur `Ouvrir le Terminal ici`.
- Pointez **cmd** sur une commande `cm_` pour donner à une action intégrée sa propre entrée de menu Démarrer et son raccourci.
- L'ordre dans le fichier est l'ordre dans le menu, alors placez vos commandes les plus utilisées en haut.

## Remarques

- Vous pouvez aussi remplacer toute la barre de menus par la vôtre. Choisissez **Configuration > Modifier le fichier de menu…** pour ouvrir un fichier de menu initialisé à partir du menu intégré actuel, entièrement localisé ; modifiez-le librement et vos changements s'appliquent la prochaine fois que l'application est activée. Supprimez le fichier pour rétablir la barre de menus standard.
