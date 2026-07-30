---
title: Déplacer et renommer
slug: moving-and-renaming
section: Fichiers et dossiers
order: 26
related: [copying-files, multi-rename]
---

Déplacer relocalise les fichiers et les dossiers au lieu de les dupliquer, et renommer change leur nom sans toucher à leur contenu. Comme Peach Commander affiche deux panneaux côte à côte, déplacer revient simplement à choisir ce que vous voulez dans un panneau et à l'envoyer vers le dossier ouvert dans l'autre. Vous pouvez aussi renommer un élément sur place, ou donner à la volée de nouveaux noms aux éléments déplacés à l'aide d'un masque à caractères génériques.

## Déplacer des fichiers vers l'autre panneau

1. Dans le panneau source, ouvrez le dossier qui contient les éléments que vous souhaitez déplacer, et ouvrez le dossier de destination dans l'autre panneau.
2. Sélectionnez le fichier ou le dossier à déplacer. Pour en déplacer plusieurs à la fois, sélectionnez-les tous d'abord (voir *Sélectionner des fichiers*).
3. Appuyez sur F6, ou choisissez **Fichier > Déplacer**.
4. Vérifiez le dossier cible indiqué dans la boîte de dialogue et cliquez sur **OK** (ou appuyez sur Return) pour lancer le déplacement.

![La boîte de dialogue de déplacement affichant le champ du chemin cible, les options et une case pour la file d'attente](screenshots/copy-dialog.png)
*(Figure : la boîte de dialogue de déplacement utilise le même champ cible que la copie — saisissez un chemin, ou ajoutez un masque à caractères génériques pour renommer au moment du déplacement.)*

Les déplacements sur le même disque sont quasi instantanés. Lorsque la destination se trouve sur un autre disque, Peach Commander copie les éléments puis ne supprime les originaux qu'une fois que chaque fichier est arrivé à bon port.

## Renommer sur place

1. Sélectionnez un seul fichier ou dossier.
2. Appuyez sur Shift+F6, ou choisissez **Fichier > Renommer**.
3. Modifiez le nom directement dans le panneau, puis appuyez sur Return pour confirmer ou Esc pour annuler.

## Renommer pendant le déplacement

Le champ cible de la boîte de dialogue de déplacement accepte un masque à caractères génériques, ce qui vous permet de renommer les éléments au moment où ils sont déplacés :

1. Sélectionnez les éléments et appuyez sur F6.
2. Dans le champ cible, ajoutez un masque de nom après le dossier de destination, par exemple `/Users/you/Archive/*_backup.*`.
3. `*` représente le nom d'origine et `.*` l'extension d'origine. Confirmez pour déplacer et renommer en une seule étape.

## Raccourcis

| Action | Raccourci |
| --- | --- |
| Déplacer vers l'autre panneau | F6 |
| Renommer sur place | Shift+F6 |

## Astuces

- La boîte de dialogue de déplacement propose le même bouton d'options et la même case de file d'attente en arrière-plan que la copie : vous pouvez donc mettre en file d'attente les déplacements volumineux et les laisser s'exécuter en arrière-plan.
- Déplacer au sein du même disque est une opération rapide sur place, sans risque même pour de très gros dossiers. Un déplacement entre disques prend plus de temps, car les données sont d'abord copiées, puis la source est supprimée.
- Pour renommer de nombreux fichiers d'un coup avec numérotation, rechercher-remplacer ou motifs, utilisez plutôt l'outil de renommage multiple (voir *Renommage multiple*).
