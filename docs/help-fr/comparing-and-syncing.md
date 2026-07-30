---
title: Comparer et synchroniser
slug: comparing-and-syncing
section: Outils avancés
order: 90
related: [multi-rename]
---

Lorsque vous conservez deux copies d'un même dossier — un dossier de travail et une sauvegarde, un ordinateur portable et un partage réseau, un projet et son archive —, Peach Commander vous aide à voir exactement ce qui a changé et à remettre les deux côtés en phase. Vous pouvez synchroniser deux répertoires, comparer des fichiers individuels ligne par ligne, et inspecter des fichiers octet par octet lorsque vous avez besoin de certitude jusqu'au dernier caractère.

## Synchroniser deux répertoires

1. Ouvrez le dossier que vous souhaitez synchroniser dans le panneau gauche et le dossier auquel le comparer dans le panneau droit.
2. Choisissez **Commandes ▸ Synchroniser les dossiers…**. Les chemins des deux dossiers sont renseignés à partir de vos panneaux.
3. Définissez le degré de minutie de la comparaison : inclure les sous-dossiers, comparer **par contenu** (pas seulement par date et taille), ou ignorer la date de modification.
4. Ajoutez un masque de filtre (par exemple `*.jpg;*.png`) si vous ne voulez synchroniser que certains fichiers.
5. Examinez la grille de résultats. Chaque ligne affiche un fichier à gauche, une flèche de direction au milieu, et le fichier correspondant à droite. Les flèches indiquent ce qui va se passer : **→** copie de gauche à droite, **←** copie de droite à gauche, et **=** signifie que les deux sont identiques.
6. Ajustez des lignes individuelles si vous n'êtes pas d'accord avec une direction proposée, puis cliquez sur le bouton de synchronisation pour appliquer les modifications.

![La fenêtre de synchronisation des dossiers avec deux chemins de dossiers et une grille de résultats de fichiers comportant des flèches gauche, égal et droite](screenshots/sync-dialog.png)
*(Figure : la fenêtre Synchroniser les dossiers compare les deux côtés et propose une direction de copie pour chaque fichier.)*

## Comparer deux fichiers par contenu

1. Sélectionnez un fichier dans chaque panneau (ou deux fichiers dans le même panneau).
2. Choisissez **Fichier ▸ Comparer par contenu…**.
3. Les deux fichiers s'ouvrent côte à côte avec leurs différences mises en évidence. Utilisez les commandes suivant/précédent pour passer d'un bloc modifié à l'autre.
4. Si vous activez le mode édition, vous pouvez ajuster directement l'un ou l'autre fichier et enregistrer vos modifications.

![La fenêtre de comparaison affichant deux fichiers texte côte à côte avec les lignes différentes mises en évidence](screenshots/diff-window.png)
*(Figure : comparaison de deux fichiers texte ; les lignes modifiées sont mises en évidence des deux côtés.)*

## Comparer des fichiers octet par octet

Lorsque deux fichiers semblent identiques mais que vous devez prouver qu'ils le sont réellement (ou trouver le seul octet qui diffère), utilisez la comparaison binaire. Elle affiche les deux fichiers dans une vue hexadécimale avec les octets non concordants marqués, ce qui est idéal pour vérifier des téléchargements, contrôler des données encodées ou confirmer une copie exacte.

## Comparer les listes de répertoires

Pour repérer d'un coup d'œil les différences entre deux dossiers ouverts, choisissez **Sélection ▸ Comparer les dossiers** (Shift+F2). Peach Commander marque les fichiers qui diffèrent ou qui manquent de l'autre côté, afin que vous puissiez agir dessus avec les commandes habituelles de copie, déplacement et suppression.

## Raccourcis

| Action | Raccourci |
| --- | --- |
| Comparer les listes de répertoires (marquer les fichiers différents) | Shift+F2 |
| Comparer par contenu | Fichier ▸ Comparer par contenu… |
| Synchroniser les répertoires | Commandes ▸ Synchroniser les dossiers… |

## Remarques

- **Par contenu ou par date/taille.** Une comparaison rapide fait correspondre les fichiers par taille et date de modification, ce qui est rapide mais peut être trompé lorsque les horodatages diffèrent pour des fichiers identiques. Activez **par contenu** pour un résultat fiable, au prix de la lecture de chaque fichier.
- **Sous-dossiers et filtres.** La fenêtre de synchronisation peut descendre dans les sous-dossiers et peut être limitée par un masque de filtre : vous pouvez ainsi synchroniser uniquement les types de fichiers qui vous intéressent.
- **Vous gardez le contrôle.** La synchronisation ne s'exécute jamais toute seule — vous examinez les directions proposées dans la grille de résultats et pouvez en modifier n'importe laquelle avant qu'aucun fichier ne soit copié.
- **Préréglages.** Les configurations de synchronisation fréquemment utilisées peuvent être enregistrées et réutilisées afin que vous n'ayez pas à ressaisir les mêmes options à chaque fois.
