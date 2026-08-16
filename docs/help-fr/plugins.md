---
title: Extensions
slug: plugins
section: Extensions
order: 120
related: [disk-map, ai-assistant, git, system-monitor, task-manager, uninstaller, filesystem-images, archives, ftp-and-sftp]
---

Les extensions étendent Peach Commander avec des outils supplémentaires, des formats de fichiers et des emplacements à parcourir. Une douzaine d'extensions sont intégrées, vous pouvez donc les utiliser immédiatement, et vous pouvez activer ou désactiver des extensions individuelles — ou en installer de nouvelles — depuis une seule fenêtre. Utilisez les extensions quand vous voulez des capacités au-delà de la copie et de la navigation quotidiennes : visualiser ce qui remplit un disque, se connecter à un serveur WebDAV, vérifier l'état d'un dépôt Git, surveiller l'activité du système, et plus encore.

Les extensions se déclinent en quelques variétés : certaines ajoutent un **panneau ou une barre latérale** (une vue), certaines ajoutent des **colonnes** à la liste de fichiers, certaines ajoutent un **emplacement dans lequel vous naviguez** comme un lecteur, et certaines apprennent à l'application un nouveau **format d'archive**. Chacune s'active indépendamment.

## Ce que les extensions intégrées ajoutent

Plusieurs extensions ont leur propre rubrique d'aide détaillée — suivez le lien pour l'histoire complète :

- **[Carte du disque](disk-map.md)** — visualise ce qui remplit un dossier ou un volume sous forme de treemap ou de sunburst, réconcilié avec l'espace libre, purgeable et masqué, avec un collecteur de nettoyage.
- **[Assistant IA](ai-assistant.md)** — un assistant facultatif et amovible qui résume, renomme, traduit, met en tableau et organise les fichiers en langage naturel, sur l'appareil ou via un modèle cloud.
- **[Git](git.md)** — affiche le statut de chaque fichier dans l'arbre de travail et la branche courante sous forme de colonnes de panneau, et ajoute un menu **Git** pour le statut, l'indexation, le commit, le pull et le push.
- **[System Monitor](system-monitor.md)** — un relevé en temps réel du processeur, de la mémoire, du disque, du réseau (et, là où c'est disponible, du GPU, de la batterie, des capteurs) dans la barre de titre de la fenêtre, avec des graphiques de détail au clic.
- **[Task Manager](task-manager.md)** — monte vos processus en cours comme un lecteur **TaskManager** parcourable ; triez-les, examinez-les comme des fichiers, ou terminez-les avec Supprimer.
- **[Images de systèmes de fichiers](filesystem-images.md)** — ouvre une image de système de fichiers (SquashFS, ext, Btrfs, JFFS2, UBIFS, cramfs, initramfs, FAT, exFAT, NTFS) comme une archive, y compris les images disque à plusieurs partitions. En lecture seule, et désactivé tant que vous ne l'activez pas.
- **[Uninstaller](uninstaller.md)** — retire une application **et** les fichiers de support, caches et préférences qu'elle laisse derrière elle, après vous avoir montré exactement ce qui va partir.

Les autres extensions intégrées sont plus petites et n'ont pas besoin de leur propre page :

- **WebDAV** — connectez-vous à un serveur WebDAV (**Réseau ▸ Connexion WebDAV…**) et parcourez-le, téléversez, téléchargez, renommez et supprimez dessus comme s'il s'agissait d'un dossier. Les mots de passe sont conservés dans le trousseau macOS.
- **iCloud Drive** — ajoute une entrée *iCloud Drive* à la barre de lecteurs qui saute directement à votre dossier iCloud Drive local. Elle n'apparaît que lorsqu'iCloud Drive est configuré sur votre Mac.
- **Notes** — gardez une note à côté de n'importe quel fichier ou dossier. Une petite pastille **●** marque les éléments qui en ont une ; modifiez les notes dans une barre latérale **Notes** ancrée ou un éditeur de texte enrichi complet (**Commandes ▸ Modifier la note…**), et parcourez-les toutes avec **Vue d'ensemble des notes…**.
- **Log Viewer** — ouvrez un fichier comme un journal coloré, classé par niveau et suivi en direct (**Fichier ▸ Afficher comme journal…**), avec des filtres par niveau, une recherche et la prise en charge des formats de journaux courants ainsi que de vos propres formats regex. Gère instantanément des journaux de plusieurs gigaoctets.
- **CSV Lister** — appuyez sur F3 sur un fichier `.csv` ou `.tsv` et il s’ouvre comme un vrai tableau à colonnes triables au lieu de texte brut. Le séparateur est détecté automatiquement, donc les exports séparés par des points-virgules s’alignent aussi, et la recherche de la visionneuse trouve les valeurs cellule par cellule.
- **AI Column** — ajoute une colonne *Langue IA* qui détecte la langue dominante de chaque fichier texte sur l'appareil (à l'aide du framework NaturalLanguage d'Apple — pas un modèle cloud).
- **Formats d'archives** — apprennent à l'application à parcourir et extraire davantage de types d'archives (7z, famille tar, gzip/bzip2/xz/zstd, et RAR là où un outil auxiliaire est installé), qui s'ouvrent alors comme des dossiers.

## Activer ou désactiver des extensions

1. Choisissez Configuration ▸ Extensions… pour ouvrir la fenêtre des extensions.
2. Chaque extension installée apparaît dans la liste avec son nom, son type et une case « Activé ».
3. Cochez ou décochez la case pour activer ou désactiver une extension. Les changements prennent effet immédiatement — les extensions activées ajoutent leurs menus, colonnes et fonctions ; les désactivées restent à l'écart.

![La fenêtre des extensions listant les extensions installées avec des cases à cocher et les boutons Installer et Retirer](screenshots/plugins-window.png)
*(Figure : la fenêtre des extensions, où vous activez, désactivez, installez ou retirez des extensions.)*

## Installer une nouvelle extension

1. Choisissez Configuration ▸ Extensions….
2. Cliquez sur **Installer depuis un dossier…**.
3. Choisissez un paquet d'extension ou un `.zip` qui en contient un, et confirmez. L'extension est ajoutée à la liste et activée.

## Retirer une extension

1. Dans la fenêtre des extensions, marquez l'extension dans la liste.
2. Cliquez sur **Retirer**. Les fonctions intégrées ne sont pas affectées ; seule l'extension sélectionnée est retirée.

## Remarques

- La liste des extensions affiche le type et la version d'interface de chaque extension à côté de son nom et de son emplacement, pour que vous puissiez confirmer ce qui est installé.
- Si aucune extension n'est installée, la fenêtre affiche une brève invite vous dirigeant vers **Installer depuis un dossier…**.
- Certaines extensions ajoutent leurs propres colonnes, éléments de menu ou emplacements de panneau uniquement lorsqu'elles sont activées. Si une fonction attendue manque, vérifiez que l'extension est activée ici.
