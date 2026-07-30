---
title: Nouveaux dossiers et fichiers
slug: creating-items
section: Fichiers et dossiers
order: 30
related: [opening-files]
---

Lorsque vous organisez des fichiers, vous avez souvent besoin d'un nouvel endroit où les ranger ou d'un document vierge pour démarrer. Peach Commander vous permet de créer un nouveau dossier ou un nouveau fichier texte directement dans le panneau où vous travaillez, sans passer par le Finder. Les nouveaux éléments sont créés dans le dossier actuellement affiché dans le panneau actif.

## Créer un nouveau dossier

1. Cliquez sur le panneau où vous voulez que le nouveau dossier apparaisse pour l'activer.
2. Appuyez sur F7.
3. Saisissez un nom dans la zone qui apparaît.
4. Appuyez sur Return (ou cliquez sur OK). Le nouveau dossier apparaît dans le panneau, prêt à l'emploi.

Vous pouvez faire plus que créer un seul dossier en une étape :

- **Dossiers imbriqués d'un coup.** Saisissez un chemin avec des barres obliques, comme `a/b/c`, pour créer un dossier `a` contenant `b` contenant `c`. Les niveaux qui n'existent pas encore sont créés pour vous.
- **Plusieurs dossiers à la fois.** Séparez les noms par une barre verticale, comme `d1|d2`, pour créer `d1` et `d2` côte à côte. Vous pouvez combiner les deux styles, par exemple `reports/2026|archive`.

## Créer un nouveau fichier texte

1. Cliquez sur le panneau où vous voulez que le nouveau fichier apparaisse.
2. Appuyez sur Shift+F4.
3. Saisissez un nom pour le fichier, y compris son extension (par exemple `notes.txt`).
4. Appuyez sur Return. Le fichier vide est créé et s'ouvre dans votre éditeur afin que vous puissiez commencer à taper immédiatement.

Le fichier s'ouvre dans l'éditeur que Peach Commander est configuré pour utiliser avec ce type de fichier. Consultez **Ouvrir et afficher des fichiers** pour savoir comment fonctionne l'édition.

## Raccourcis

| Action | Touche |
| --- | --- |
| Nouveau dossier | F7 |
| Nouveau fichier texte | Shift+F4 |

## Remarques

- Sous macOS, un nom de dossier ou de fichier peut contenir presque n'importe quel caractère. Seule la barre oblique `/` (utilisée comme séparateur de chemin pour les dossiers imbriqués) et quelques caractères réservés ne sont pas autorisés dans un même nom.
- Utiliser deux-points `:` dans un nom est possible mais peut prêter à confusion dans le Finder, mieux vaut donc l'éviter.
- Si un dossier portant le même nom existe déjà, Peach Commander conserve simplement l'existant — rien n'est écrasé.
