---
title: Sélectionner des fichiers
slug: selecting-files
section: Fichiers et dossiers
order: 22
related: [copying-files, searching]
---

Avant de copier, déplacer, supprimer ou compresser quoi que ce soit, vous indiquez d'abord à Peach Commander sur quels éléments agir. L'élément sur lequel se trouve votre curseur est toujours l'élément courant, mais vous pouvez aussi *marquer* un ou plusieurs fichiers et dossiers pour qu'une commande s'exécute sur l'ensemble d'un coup. Les éléments marqués se distinguent par une couleur de nom particulière dans le panneau.

## Marquer des fichiers et des dossiers

1. Cliquez sur une ligne pour y amener le curseur. Un simple clic ne sélectionne que cet élément.
2. Pour marquer plusieurs éléments à la fois, maintenez Cmd et cliquez sur chacun d'eux, ou maintenez Shift et cliquez pour marquer une plage.
3. Pour marquer l'élément sous le curseur et descendre en un seul geste, appuyez sur Insert. Appuyez plusieurs fois pour marquer rapidement une série d'éléments consécutifs. La barre d'espace bascule également la marque de l'élément courant (et affiche la taille d'un dossier).
4. Pour tout marquer dans le panneau, choisissez Sélection > Tout sélectionner (Ctrl+Num+), ou appuyez sur Cmd+A. Choisissez Sélection > Tout désélectionner (Ctrl+Num-) pour effacer toutes les marques.

## Sélectionner ou désélectionner selon un motif

1. Choisissez Sélection > Sélectionner un groupe… (Num+) pour ajouter les éléments dont le nom correspond à un motif, ou Sélection > Désélectionner un groupe… (Num-) pour retirer les éléments correspondants des marques actuelles.
2. Saisissez un masque avec caractères génériques. Utilisez `*` pour n'importe quels caractères et `?` pour un seul caractère. Séparez plusieurs masques par un point-virgule, et indiquez les exceptions après une barre verticale — par exemple `*.jpg;*.png` marque toutes les images, et `*.*|*.bak` marque tout sauf les fichiers de sauvegarde.

![La boîte de dialogue Sélectionner un groupe avec un masque à caractères génériques saisi dans le champ de motif](screenshots/select-by-mask.png)
*(Figure : marquer des fichiers à l'aide d'un masque à caractères génériques.)*

## Inverser, même extension et restaurer

- **Inverser la sélection** (Num*, menu Sélection) inverse chaque marque : les éléments marqués deviennent non marqués et inversement — pratique pour « tout sauf ceux-ci ».
- **Sélectionner tout avec la même extension** (Alt+Num+, menu Sélection) marque tous les fichiers qui partagent l'extension de l'élément sous le curseur : une seule frappe saisit ainsi tous les fichiers `.pdf`, par exemple.
- **Restaurer la sélection** (Num/, menu Sélection) rétablit votre ensemble de marques précédent — utile si une commande les a effacées ou si vous avez marqué le mauvais groupe.

## Raccourcis

| Action | Touche |
|---|---|
| Basculer la marque, descendre | Insert |
| Basculer la marque (élément courant) | Space |
| Tout sélectionner / Tout désélectionner | Ctrl+Num+ / Ctrl+Num- |
| Tout sélectionner (autre méthode) | Cmd+A |
| Sélectionner un groupe par masque | Num+ |
| Désélectionner un groupe par masque | Num- |
| Inverser la sélection | Num* |
| Sélectionner tout avec la même extension | Alt+Num+ |
| Restaurer la sélection précédente | Num/ |

## Remarques

- Les marques et le curseur sont indépendants : déplacer le curseur avec les touches fléchées ne change pas ce qui est marqué.
- L'entrée du dossier parent (`..`) ne peut jamais être marquée.
- Sélectionner un groupe, Désélectionner un groupe et Inverser la sélection s'appliquent au nom du fichier : vous pouvez donc inclure ou exclure les dossiers selon les options de la boîte de dialogue.
- Une fois une copie, un déplacement ou une suppression terminé, les éléments traités avec succès sont démarqués automatiquement, tandis que ceux qui ont échoué restent marqués pour que vous puissiez réessayer.
