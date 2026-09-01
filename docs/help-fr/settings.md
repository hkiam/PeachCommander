---
title: Réglages
slug: settings
section: Personnalisation
order: 116
related: [appearance, keyboard-shortcuts]
---

La fenêtre Réglages est l'endroit où vous adaptez Peach Commander à votre façon de travailler : quelles barres apparaissent, comment les fichiers sont affichés, comment se comportent les opérations de copie et de suppression, le format d'archive utilisé quand vous compressez, le comportement des onglets, les valeurs FTP par défaut, la langue d'affichage, et plus encore. Les réglages sont regroupés en pages pour que vous trouviez rapidement une option, et chaque changement est enregistré automatiquement dans votre dossier de configuration personnel.

## Ouvrir les Réglages

1. Choisissez **Peach Commander > Réglages…**, ou appuyez sur Cmd+, (virgule).
2. Vous pouvez aussi ouvrir la même fenêtre depuis **Configuration > Options…**.
3. Choisissez une page dans la liste de gauche ; les options de cette page apparaissent à droite.
4. Ajustez les contrôles. Les changements prennent effet immédiatement sauf si une note sur la page indique le contraire.
5. Pour aller droit à une option, saisissez du texte dans le champ de recherche en haut de la fenêtre. Les réglages correspondants de *toutes* les pages sont listés avec la page où chacun se trouve, et en choisir un ouvre cette page avec le réglage mis en évidence. ↑/↓ parcourent les résultats, Retour ouvre celui qui est sélectionné, et Échap quitte la recherche et rétablit la page d'où vous venez.

![La fenêtre Réglages montrant la page Disposition avec des cases pour les barres d'interface](screenshots/settings-layout.png)
*(Figure : la page Disposition contrôle quelles barres sont affichées autour des panneaux.)*

## Les pages

La fenêtre comporte ces pages, dans l'ordre :

- **Disposition** — afficher ou masquer la barre de lecteurs, la barre d'onglets, la barre de chemin et la barre d'état, et choisir les pages proposées par le panneau latéral.
- **Affichage** — comment les fichiers et dossiers sont listés, y compris le format de date.
- **Icônes** — l'apparence des icônes dans les listes de fichiers.
- **Fonctionnement** — comportement général, comme ce qui se passe quand vous saisissez dans un panneau (recherche rapide ou ligne de commande).
- **Couleurs** — couleurs personnalisées des panneaux, ou les laisser suivre le thème actuel.
- **Confirmation** — quelles actions vous demandent d'abord de confirmer, comme la suppression.
- **Modifier/Afficher** — si l'enregistrement dans l'éditeur conserve une copie de sauvegarde `.bak`, les programmes utilisés pour modifier et afficher les fichiers, les associations par type, et ce qu'un aperçu a le droit de coûter sur les emplacements réseau et dans les archives.
- **Copier/Supprimer** — préserver les métadonnées des fichiers, utiliser le clonage rapide, ne copier que les fichiers plus récents, vérifier après copie, envoyer les suppressions à la corbeille et définir une limite de vitesse facultative.
- **Zip/Compresseur** — le format d'archive et le niveau de compression par défaut utilisés quand vous compressez.
- **Extensions** — activer ou désactiver les extensions installées.
- **Onglets** — comment les onglets de dossiers s'ouvrent et se comportent.
- **FTP** — valeurs réseau par défaut telles que l'intervalle keep-alive.
- **Clavier** — consulter et changer les raccourcis clavier.
- **Langue** — choisir Réglage système, English ou Deutsch.
- **IA** — configurer l'assistant IA : modèle préféré, point de terminaison et clé cloud, autonomie et serveur MCP facultatif (voir [Assistant IA](ai-assistant.md)).
- **Divers** — ouvrir votre dossier de configuration dans le Finder.

Les extensions activées peuvent ajouter leurs propres pages après les pages intégrées — par exemple **Carte du disque** et **System Monitor** — de sorte que leurs options vivent dans la même fenêtre (voir [Extensions](plugins.md)).

![La fenêtre Réglages montrant les options de la page Affichage pour le listage des fichiers](screenshots/settings-display.png)
*(Figure : la page Affichage contrôle comment les fichiers et dossiers sont listés.)*

![La fenêtre Réglages montrant la page Fonctionnement](screenshots/settings-operation.png)
*(Figure : la page Fonctionnement régit la recherche rapide et le comportement de la souris.)*

## Où sont stockés vos réglages

Votre configuration est conservée dans des fichiers en texte brut à l'intérieur de votre dossier Application Support personnel, à `~/Library/Application Support/PeachCommander`. Pour l'ouvrir, allez à la page **Divers** et cliquez sur **Ouvrir le dossier de configuration**. Les mots de passe FTP enregistrés ne sont pas stockés dans ces fichiers ; ils sont conservés en sécurité dans le trousseau macOS.

Les réglages sont écrits à mesure que vous les changez. Vous pouvez aussi forcer un enregistrement à tout moment avec **Configuration > Enregistrer les réglages**, et mémoriser la position actuelle de la fenêtre et la disposition des panneaux avec **Configuration > Enregistrer la position**.

## Récupérer des réglages depuis Total Commander

Si vous migrez depuis Total Commander sous Windows, vous pouvez importer vos sites FTP enregistrés. Choisissez **Configuration > Importer wincmd.ini…** et sélectionnez votre fichier de configuration FTP de Total Commander. Vos connexions sont ajoutées à Peach Commander dans le même ordre qu'elles y apparaissaient.

## Raccourcis

| Action | Raccourci |
| --- | --- |
| Ouvrir les Réglages | Cmd+, |

## Remarques

- La page **Langue** propose Réglage système, English et Deutsch. Changer de langue ne prend effet qu'après avoir redémarré Peach Commander.
- Les couleurs définies sur la page **Couleurs** remplacent le thème ; utilisez **Réinitialiser aux valeurs par défaut** là-bas pour revenir aux couleurs du thème.
- Peach Commander stocke ses réglages uniquement dans son propre dossier de configuration, de sorte que vos changements n'affectent jamais d'autres applications et sont faciles à sauvegarder en copiant ce dossier.
