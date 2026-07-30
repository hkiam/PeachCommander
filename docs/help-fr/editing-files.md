---
title: Modifier des fichiers
slug: editing-files
section: Affichage et édition
order: 72
related: [viewing-files]
---

Quand vous avez besoin de modifier un fichier plutôt que de simplement le consulter, Peach Commander l'ouvre dans un éditeur intégré. Les fichiers texte et code s'ouvrent dans un éditeur complet avec coloration syntaxique, recherche et remplacement, un plan des symboles de votre code et une minicarte pour une navigation rapide. Les fichiers binaires peuvent s'ouvrir dans un éditeur hexadécimal distinct, où vous pouvez inspecter et modifier des octets individuels. Vous n'avez jamais à quitter l'application pour une modification rapide.

## Modifier un fichier texte ou code

1. Dans l'un ou l'autre panneau, placez le curseur sur le fichier à modifier.
2. Appuyez sur F4, ou choisissez Fichier ▸ Modifier. Le fichier s'ouvre dans la fenêtre de l'éditeur.
3. Effectuez vos modifications. Si le fichier est un format de programmation ou de données reconnu, les mots-clés, chaînes et commentaires sont colorés automatiquement.
4. Appuyez sur Cmd+S (ou cliquez sur Enregistrer) pour écrire vos modifications. Le premier enregistrement conserve une sauvegarde de l'original à côté du fichier, afin que vous puissiez toujours y revenir.

Pour créer un tout nouveau fichier texte à l'emplacement courant, appuyez sur Maj+F4.

![L'éditeur de texte intégré montrant la coloration syntaxique, le plan des symboles et la minicarte](screenshots/editor.png)
*(Figure : l'éditeur avec la coloration syntaxique, le plan des symboles à gauche et la minicarte à droite.)*

## Rechercher, remplacer et naviguer

- Appuyez sur Cmd+F pour ouvrir la barre de recherche. Pour remplacer du texte, ouvrez la barre de recherche et basculez-la vers la vue de remplacement, ou cliquez sur Rechercher/Remplacer dans la barre d'outils.
- Cliquez sur Formater JSON/XML pour réindenter un document JSON ou XML en une mise en page propre et lisible.
- Cliquez sur Symboles (ou appuyez sur Cmd+Maj+O) pour afficher une barre latérale listant les classes, fonctions et méthodes de votre code. Cliquez sur une entrée pour y sauter directement.
- Appuyez sur Cmd+L pour sauter à une ligne précise.
- Appuyez sur Cmd+\ pour sauter entre une parenthèse et son homologue correspondant.
- Cliquez sur le bouton carte pour afficher ou masquer la minicarte, un aperçu à l'échelle de tout le fichier sur lequel vous pouvez cliquer pour faire défiler.
- Utilisez le menu Encodage de la barre d'outils si le fichier a été enregistré avec un encodage autre que celui par défaut.

## Modifier un fichier octet par octet

1. Sélectionnez le fichier dans un panneau.
2. Choisissez Fichier ▸ Modifier en hexadécimal (ou cliquez droit sur le fichier et choisissez Modifier en hexadécimal).
3. Saisissez des chiffres hexadécimaux pour écraser des octets, ou utilisez les flèches pour parcourir le fichier. Retour arrière et Suppr retirent des octets.
4. Appuyez sur Cmd+S pour enregistrer. Comme pour l'éditeur de texte, une sauvegarde unique de l'original est conservée.

## Raccourcis

| Action | Raccourci |
|---|---|
| Modifier le fichier | F4 |
| Créer et modifier un nouveau fichier texte | Maj+F4 |
| Enregistrer | Cmd+S |
| Rechercher | Cmd+F |
| Afficher/masquer le plan des symboles | Cmd+Maj+O |
| Aller à la ligne | Cmd+L |
| Sauter à la parenthèse correspondante | Cmd+\ |
| Annuler / rétablir (éditeur hexa) | Cmd+Z / Cmd+Maj+Z |

## Remarques

- La coloration syntaxique couvre JSON, C, C#, Java, JavaScript, TypeScript, Python et Rust. Les autres types de fichiers s'ouvrent et se modifient normalement avec une coloration basique, mais la coloration détaillée et le plan des symboles ne sont disponibles que pour les langages pris en charge.
- Le plan des symboles et Aller à la ligne s'appliquent à l'éditeur de texte. L'éditeur hexadécimal est destiné à l'inspection binaire et aux modifications au niveau de l'octet, pas au texte.
- Les deux éditeurs conservent une sauvegarde du fichier original au premier enregistrement, de sorte qu'une modification accidentelle est facile à annuler en restaurant cette sauvegarde.
