---
title: Attributs et autorisations
slug: attributes-and-permissions
section: Outils avancés
order: 96
related: [file-utilities]
---

Peach Commander vous permet d'inspecter et de modifier les métadonnées de bas niveau des fichiers et dossiers que le Finder garde en grande partie hors de portée : autorisations POSIX de lecture/écriture/exécution, propriétaire et groupe, dates de modification et de création, indicateurs macOS tels que caché et verrouillé, et attributs étendus. Vous pouvez aussi modifier la liste de contrôle d'accès (ACL) d'un fichier pour des règles précises par utilisateur ou par groupe, créer des liens et des alias qui pointent vers d'autres éléments, et joindre vos propres commentaires. Ces outils s'adressent aux utilisateurs avancés qui ont besoin d'un contrôle précis sur le comportement des éléments et sur qui peut y toucher.

## Modifier les attributs

1. Sélectionnez un ou plusieurs éléments dans le panneau actif.
2. Choisissez **Fichier > Modifier les attributs…**.
3. Réglez ce dont vous avez besoin : basculez les cases lecture/écriture/exécution pour le propriétaire, le groupe et tout le monde (ou saisissez directement une valeur octale), changez le propriétaire ou le groupe, activez ou désactivez les indicateurs caché ou verrouillé, et définissez la date de modification ou de création. Utilisez **Utiliser l'heure actuelle** pour l'heure courante, ou copiez une date depuis un autre fichier.
4. Pour appliquer la même modification à travers le contenu d'un dossier, activez l'option récursive et choisissez si elle affecte les fichiers, les dossiers, ou les deux.
5. Cliquez sur OK pour appliquer la modification. Les modifications récursives s'exécutent comme une tâche en arrière-plan avec une barre de progression.

![La boîte de dialogue Modifier les attributs affichant la grille des autorisations, les indicateurs et les champs de date](screenshots/attributes-dialog.png)
*(Figure : la boîte de dialogue Modifier les attributs. Les valeurs mixtes au sein d'une sélection de plusieurs fichiers s'affichent sous forme de tiret jusqu'à ce que vous les définissiez.)*

## Modifier une ACL

Pour des règles allant au-delà du modèle de base propriétaire/groupe/tout le monde, modifiez la liste de contrôle d'accès de l'élément.

1. Ouvrez **Fichier > Modifier les attributs…** et ouvrez l'éditeur d'ACL depuis là.
2. Chaque ligne est une règle : l'utilisateur ou le groupe auquel elle s'applique, si elle autorise ou refuse, et quelles autorisations (lecture, écriture, suppression, etc.) elle accorde.
3. Ajoutez, supprimez ou modifiez des lignes, puis enregistrez pour réécrire la liste sur l'élément.

## Créer des liens, des alias et des commentaires

- **Fichier > Créer un lien symbolique…** crée un lien symbolique (symlink) qui pointe par chemin vers l'élément sous le curseur.
- **Fichier > Créer un lien physique…** crée un lien physique vers les mêmes données de fichier. Les liens physiques ne fonctionnent que pour des fichiers situés sur le même volume.
- **Fichier > Créer un alias…** crée un alias macOS que le Finder peut aussi suivre.
- **Fichier > Modifier le commentaire…** (Ctrl+Z) ouvre un éditeur de texte pour un commentaire propre au fichier. Les commentaires peuvent être affichés dans leur propre colonne et dans les infobulles d'état.

## Raccourcis

| Action | Raccourci |
| --- | --- |
| Modifier le commentaire | Ctrl+Z |

## Remarques

- Changer le propriétaire ou le groupe nécessite généralement des privilèges dont vous ne disposez pas en tant qu'utilisateur normal ; dans ce cas, la modification est signalée comme ayant échoué plutôt qu'appliquée, et le reste de vos modifications est tout de même effectué.
- Les commentaires sont stockés dans un fichier `descript.ion` à côté de vos éléments et peuvent aussi être conservés comme commentaires du Finder, selon vos réglages. Les deux sont lus lors de l'affichage d'un commentaire. Le format est celui qu'utilisent Total Commander et plusieurs autres gestionnaires de fichiers : un commentaire écrit ici y est donc lisible.
- **Un commentaire suit le fichier.** Copier, déplacer ou renommer l'emporte avec lui — vers le `descript.ion` du dossier cible lors d'un déplacement ou d'une copie, vers le nouveau nom lors d'un renommage, y compris quand vous annulez celui-ci. L'exception est l'ajout d'un fichier à la fin d'un autre : le fichier qui reste garde son propre commentaire, puisqu'il reste ce fichier.
- Si le module Notes est activé, sa barre latérale affiche et modifie ce même commentaire au-dessus du texte de la note, pour qu'il n'y ait pas deux endroits pour la même chose.
- Un lien symbolique et un alias pointent tous deux vers une cible, mais un lien symbolique stocke un simple chemin tandis qu'un alias stocke une référence macOS qui continue de fonctionner si la cible est déplacée ou renommée. Un lien physique est un second nom pour les mêmes données de fichier, pas un pointeur.
