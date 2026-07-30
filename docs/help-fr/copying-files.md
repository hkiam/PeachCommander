---
title: Copier des fichiers
slug: copying-files
section: Fichiers et dossiers
order: 24
related: [moving-and-renaming, background-transfers]
---

Peach Commander est conçu autour de deux panneaux côte à côte : l'un contient les fichiers avec lesquels vous travaillez, l'autre est la destination. Copier prend ce qui est sélectionné dans le panneau actif et en place un double dans le dossier affiché dans l'autre panneau, en laissant les originaux en place. C'est le moyen le plus rapide de dupliquer des fichiers et des dossiers entre deux emplacements sans glisser-déposer.

## Copier une sélection vers l'autre panneau

1. Dans un panneau, ouvrez le dossier qui contient les éléments que vous souhaitez copier.
2. Dans l'autre panneau, ouvrez le dossier où les copies doivent aller.
3. Sélectionnez les fichiers et dossiers à copier. Si rien n'est sélectionné, l'élément sous le curseur est utilisé.
4. Appuyez sur F5. La boîte de dialogue de copie s'ouvre, avec le chemin de destination déjà renseigné.

![La boîte de dialogue de copie avec le chemin de destination et les options](screenshots/copy-dialog.png)
*(Figure : la boîte de dialogue de copie. Le chemin cible pointe vers l'autre panneau ; utilisez les options pour affiner la copie.)*

5. Ajustez la destination si nécessaire, puis confirmez pour lancer la copie.

## Options de copie

Avant de confirmer, vous pouvez modifier le comportement de la copie :

- **Fichiers plus récents uniquement** — ignore tout élément dont la copie existe déjà et est du même âge ou plus récente, de sorte que seuls les fichiers modifiés sont mis à jour.
- **Préserver les métadonnées** — conserve les dates, les autorisations et les autres attributs de fichier sur les copies. Activé par défaut.
- **Limite de vitesse** — plafonne le débit de transfert afin qu'une copie volumineuse ne sature pas votre disque ou votre connexion réseau.
- **Masque de renommage** — saisissez un motif à caractères génériques dans le champ cible (par exemple `*.bak`) pour renommer les éléments au moment de la copie.

Vous pouvez aussi envoyer la tâche dans la file d'attente en arrière-plan au lieu de la surveiller — voir Transferts en arrière-plan.

## Progression

Une fenêtre de progression affiche le fichier en cours et l'ensemble de la tâche avec des barres distinctes, ainsi que la vitesse de transfert. Vous pouvez mettre en pause et reprendre à tout moment, ou envoyer la copie en cours vers le gestionnaire de transferts en arrière-plan pour continuer à travailler pendant qu'elle se termine.

![La boîte de dialogue de progression du transfert avec une barre de progression, le décompte des fichiers et des octets, et des boutons Pause et Annuler](screenshots/progress-dialog.png)
*(Figure : la boîte de dialogue de progression affichée pendant une copie ou un déplacement.)*

## Gérer les fichiers qui existent déjà

Si une copie devait remplacer un fichier existant, Peach Commander s'arrête et vous demande quoi faire. Un aperçu des deux fichiers vous aide à décider.

![La boîte de dialogue de conflit de remplacement comparant deux fichiers](screenshots/overwrite-dialog.png)
*(Figure : la boîte de dialogue de remplacement compare le fichier existant avec celui en cours de copie.)*

Vos choix comprennent :

- **Remplacer** le fichier existant, ou **Tout remplacer** pour appliquer ce choix à tous les conflits restants.
- **Ignorer** ce fichier, ou **Tout ignorer** pour les conflits restants.
- **Renommer** automatiquement la copie entrante afin de conserver les deux fichiers.
- **Ajouter** les données entrantes à la fin du fichier existant.
- Remplacer uniquement lorsque la source est **plus récente** ou **plus volumineuse** que le fichier existant.

## Raccourcis

| Action | Touche |
|---|---|
| Copier la sélection vers l'autre panneau | F5 |
| Copier dans le même dossier (créer un double renommé) | Shift+F5 |
| Ouvrir le gestionnaire de transferts en arrière-plan | Cmd+Shift+B |

## Remarques

- Copier entre deux emplacements sur le même disque utilise un clonage rapide lorsque le disque le prend en charge, de sorte que les fichiers volumineux se copient presque instantanément et occupent peu d'espace supplémentaire.
- Les dossiers sont copiés avec tout leur contenu.
- Pour déplacer des fichiers au lieu de les copier, utilisez F6. Pour surveiller ou gérer les tâches en file d'attente, ouvrez le gestionnaire de transferts en arrière-plan avec Cmd+Shift+B.
