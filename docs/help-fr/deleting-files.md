---
title: Supprimer des fichiers
slug: deleting-files
section: Fichiers et dossiers
order: 28
related: [copying-files]
---

Lorsque vous n'avez plus besoin de fichiers ou de dossiers, Peach Commander peut les placer dans la Corbeille afin que vous puissiez les récupérer plus tard, ou les supprimer définitivement pour libérer immédiatement de l'espace. Les suppressions s'appliquent à la sélection courante dans le panneau actif ; si rien n'est marqué, c'est l'élément sous le curseur qui est supprimé.

## Comment supprimer des fichiers

1. Dans le panneau actif, marquez les fichiers et dossiers que vous souhaitez retirer. Si vous ne marquez rien, l'élément sous le curseur est utilisé.
2. Appuyez sur **F8** (ou sur la touche **Delete**) pour placer la sélection dans la Corbeille. Pour le choisir depuis le menu, utilisez **Fichier > Supprimer**.
3. Si une confirmation apparaît, vérifiez la liste des éléments et cliquez sur **Supprimer** pour continuer, ou sur **Annuler** pour arrêter.

Les éléments envoyés à la Corbeille y restent jusqu'à ce que vous la vidiez : vous pouvez donc les restaurer depuis le Finder si vous changez d'avis.

**Édition ▸ Annuler (⌘Z) reprend la dernière suppression.** Les fichiers sortent de la Corbeille et retournent exactement là où ils étaient, sans rien écraser : un élément dont l’ancien chemin est de nouveau occupé est laissé tel quel plutôt que forcé — et l’on vous dit lesquels et pourquoi, au lieu de vous laisser supposer que tout s’est bien passé. Deux choses à savoir. Cela ne vaut que pour la *dernière* opération, et leur liste vit en mémoire : quittez l’application, ou faites trente autres opérations sur des fichiers, et l’offre a disparu alors que les fichiers sont toujours dans la Corbeille, à vous de les remettre. Et une suppression définitive (Maj+F8) ne s’annule pas du tout ; il n’y a rien à remettre en place.

## Comment supprimer définitivement

1. Marquez les fichiers et dossiers à retirer.
2. Appuyez sur **Shift+F8**, ou choisissez **Fichier > Supprimer définitivement**.
3. Confirmez la suppression. Cela contourne la Corbeille : les éléments disparaissent donc immédiatement et ne peuvent pas être récupérés.

Si certains éléments ne peuvent pas être retirés — par exemple parce qu'ils sont verrouillés ou que vous n'avez pas les autorisations —, Peach Commander vous indique lesquels ont échoué et vous permet de réessayer ou de les ignorer et de continuer avec les autres.

## Raccourcis

| Action | Raccourci |
| --- | --- |
| Supprimer vers la Corbeille | F8 ou Delete |
| Supprimer définitivement | Shift+F8 |

## Remarques

- **Confirmation.** Par défaut, Peach Commander vous demande de confirmer avant de supprimer. Vous pouvez désactiver cela dans **Configuration > Confirmation** en décochant **Confirmer avant de supprimer**. Malgré cela, traitez les suppressions définitives avec précaution, car elles sont irréversibles.
- **Comportement par défaut de F8.** Normalement, F8 place les éléments dans la Corbeille. Si vous préférez que F8 supprime définitivement par défaut, modifiez l'option de suppression dans les réglages **Configuration > Opération**. Shift+F8 supprime toujours définitivement, quel que soit ce réglage.
- **Supprimer à l'intérieur des archives.** Lorsque vous parcourez une archive prise en charge, supprimer retire les entrées sélectionnées de l'archive. Les emplacements en lecture seule, tels que certains dossiers réseau ou d'extensions, ne peuvent pas être modifiés de cette manière.
- **Dossiers.** Supprimer un dossier retire tout ce qu'il contient. Assurez-vous d'avoir sélectionné les bons éléments avant de confirmer, en particulier pour une suppression définitive.
