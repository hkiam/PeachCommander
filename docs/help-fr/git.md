---
title: Git
slug: git
section: Extensions
order: 123
related: [plugins, view-modes-and-sorting]
---

L'extension Git fait apparaître l'état d'un dépôt Git directement dans le panneau de fichiers — sans application séparée, sans terminal. Elle ajoute deux colonnes qui montrent le statut de chaque fichier dans l'arbre de travail et la branche courante, un sous-menu **Git** pour les commandes de tous les jours (statut, indexer, commit, pull, push), et elle utilise le `git` déjà installé sur votre Mac. C'est une extension, vous pouvez donc la désactiver ou la retirer dans **Configuration ▸ Extensions…**.

## Ce qu'elle ajoute

- **Deux colonnes dans la liste de fichiers** — *Statut Git* et *Branche*. Dans un dépôt, chaque fichier affiche un mot de statut court (Modifié, Ajouté, Supprimé, Non suivi, Renommé, Copié, Conflit, Ignoré ou Changé) et le panneau affiche la branche courante. Activez les colonnes dans **Configuration ▸ Colonnes…** (voir [Modes d'affichage et tri](view-modes-and-sorting.md)).
- **Un menu Git** — sous **Commandes ▸ Git**, et dans le menu contextuel d'un fichier, avec : **Statut Git…**, **Git Add (indexer)**, **Commit Git…**, **Git Pull** et **Git Push**.

![La boîte de dialogue Statut Git montrant la branche courante et les fichiers modifiés du dépôt](screenshots/git-status.png)
*(Figure : Statut Git indique la branche et chaque changement de l'arbre de travail.)*

## Vérifier le statut

1. Placez le curseur sur un fichier ou un dossier à l'intérieur d'un dépôt Git.
2. Choisissez **Commandes ▸ Git ▸ Statut Git…** (ou clic droit ▸ **Git ▸ Statut Git…**).
3. Un résumé apparaît : la branche courante (ou *(détachée)*), puis soit *Arbre de travail propre.* soit une liste de changements, chaque ligne montrant le statut et le chemin du fichier.

Si le curseur n'est pas à l'intérieur d'un dépôt, l'extension indique simplement *Pas un dépôt Git.*

## Indexer, committer, pull, push

- **Git Add (indexer)** indexe le fichier sous le curseur (`git add`).
- **Commit Git…** demande un message de commit, puis committe tous les changements (`git commit -a`). La sortie combinée est affichée pour que vous voyiez exactement ce qui s'est passé.
- **Git Pull** effectue un pull en fast-forward uniquement (`git pull --ff-only`).
- **Git Push** pousse la branche courante (`git push`).

Après une commande qui modifie le dépôt, le panneau actif se rafraîchit pour que les colonnes de statut restent à jour.

## Remarques

- L'extension utilise le Git système à `/usr/bin/git`. Si Git n'est pas installé, les commandes signalent que Git n'est pas disponible. (L'installation des Xcode Command Line Tools le fournit.)
- Le statut du dépôt est lu une fois par dossier et mis en cache, si bien que le défilement d'un gros dépôt reste rapide ; le cache se rafraîchit après toute commande qui modifie l'arbre.
- Le commit utilise `git commit -a`, qui committe les changements suivis ; les fichiers tout neufs nécessitent d'abord **Git Add (indexer)**.
- Les en-têtes des colonnes *Statut Git* et *Branche* s'affichent actuellement en anglais même dans d'autres langues d'interface ; les valeurs et les boîtes de dialogue sont localisées.
