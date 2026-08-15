---
title: Historique global
slug: history
section: Organiser l'affichage
order: 47
related: [favorites, navigating]
---

L’historique global est une fenêtre qui se souvient de votre propre travail : dossiers visités, fichiers ouverts, opérations effectuées et commandes exécutées. Appuyez sur Ctrl+Cmd+H depuis n’importe où, commencez à taper, et vous êtes revenu au dossier d’hier en une seconde — sans la souris.

## Ouvrir l’historique

1. Appuyez sur Ctrl+Cmd+H, ou choisissez **Aller > Historique…**. Le panneau actif n’a pas d’importance.
2. Tapez quelques lettres. La correspondance n’a pas besoin d’être exacte ni contiguë : `proj rep` trouve `~/Projects/annual-report.txt`.
3. Parcourez les résultats avec les flèches Haut et Bas tout en continuant à taper.
4. Retour agit sur l’entrée sélectionnée, Échap ferme la fenêtre.

Les entrées sont classées selon la récence *et* la fréquence de leur usage : les endroits où vous travaillez le plus sont donc déjà en haut. Les entrées épinglées passent toujours en premier.

![The global history window listing recently visited folders and opened files](screenshots/history-palette.png)
*(Figure : L’historique global — le champ de recherche a le focus, et la liste est classée selon la récence et la fréquence d’usage de chaque entrée.)*

## Filtrer par type

Les boutons sous le champ de recherche limitent la liste à toutes les entrées, aux dossiers, aux fichiers, aux opérations ou aux favoris. Option+1 à Option+5 passent de l’un à l’autre au clavier.

## Agir sur une entrée

| Action | Raccourci |
| --- | --- |
| Ouvrir l’entrée sélectionnée | Return |
| L’afficher dans le panneau, curseur dessus | Option+Return |
| Ouvrir l’une des neuf entrées les plus pertinentes | Cmd+1 … Cmd+9 |
| Changer le panneau d’ouverture | Tab |
| Épingler ou détacher l’entrée | Cmd+P |
| Retirer l’entrée de l’historique | Cmd+Delete |
| Copier le chemin de l’entrée | Option+Cmd+C |
| Afficher l’entrée dans le Finder | Cmd+Shift+R |
| Fermer l’historique | Esc |

Retour fait ce que l’entrée mérite : un dossier s’ouvre dans le panneau cible, un fichier s’ouvre comme il le ferait depuis le panneau, et une ligne de commande est placée dans la ligne de commande pour que vous la relisiez et l’exécutiez. Le panneau cible est nommé en bas de la fenêtre et Tab le change.

## Répéter une opération

Une copie ou un déplacement apparaît sous **Opérations**, et Retour le relance — les mêmes éléments vers le même dossier, par la file de transfert habituelle et ses questions de remplacement. Les éléments disparus sont ignorés, et s’il n’en reste aucun on vous le dit.

Les suppressions et les renommages sont listés mais jamais répétés : Retour montre où ils ont eu lieu. Répéter une suppression ne doit pas se trouver à une touche près dans une liste que l’on parcourt.

## Garder l’historique sous contrôle

Réglages ▸ Divers décide si un historique est tenu, combien d’entrées il conserve et après combien de jours il les oublie. Les entrées épinglées y échappent et 0 jour conserve tout ; la liste réside dans `history.ini` de votre dossier de configuration et survit aux redémarrages.

## Remarques

- Ouvrir quelque chose depuis l’historique compte comme un usage : c’est pourquoi ce que vous reprenez ne cesse de remonter.
- Les dossiers dans une archive, sur un serveur ou dans un volume de module ne sont pas mémorisés : un tel chemin ne veut rien dire sans le montage qui l’a produit, et l’historique propre au panneau les garde tant qu’il est ouvert.
- Ce n’est pas l’historique de dossiers propre au panneau, sur Option+Bas, qui liste seulement où ce panneau est passé, dans l’ordre.
