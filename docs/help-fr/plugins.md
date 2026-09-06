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

- **Amazon S3** — connectez-vous à Amazon S3 ou à un stockage compatible S3 (**Réseau ▸ Se connecter à Amazon S3…**) et parcourez les buckets comme des dossiers, avec lecture, écriture, renommage et suppression. Les clés secrètes sont conservées dans le trousseau de macOS.
- **WebDAV** — connectez-vous à un serveur WebDAV (**Réseau ▸ Connexion WebDAV…**) et parcourez-le, téléversez, téléchargez, renommez et supprimez dessus comme s'il s'agissait d'un dossier. Les mots de passe sont conservés dans le trousseau macOS.
- **iCloud Drive** — ajoute une entrée *iCloud Drive* à la barre de lecteurs qui saute directement à votre dossier iCloud Drive local. Elle n'apparaît que lorsqu'iCloud Drive est configuré sur votre Mac.
- **Notes** — gardez une note à côté de n'importe quel fichier ou dossier. Une petite pastille **●** marque les éléments qui en ont une ; modifiez les notes dans une barre latérale **Notes** ancrée ou un éditeur de texte enrichi complet (**Commandes ▸ Modifier la note…**), et parcourez-les toutes avec **Vue d'ensemble des notes…**.
- **Log Viewer** — ouvrez un fichier comme un journal coloré, classé par niveau et suivi en direct (**Fichier ▸ Afficher comme journal…**), avec des filtres par niveau, une recherche et la prise en charge des formats de journaux courants ainsi que de vos propres formats regex. Gère instantanément des journaux de plusieurs gigaoctets.
- **Markdown and HTML** — appuyez sur F3 sur un fichier `.md` ou `.html` et lisez-le mis en forme plutôt qu'en source, avec les diagrammes ` ```mermaid ` dessinés et les mathématiques `$…$` composées sur votre Mac. Rien n'est téléchargé et aucune partie du document n'est envoyée où que ce soit.
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

Une extension que vous téléchargez arrive sous forme de **paquet d'extension** — un fichier se terminant par `.pcplug`. Il y a quatre façons de l'installer, et toutes aboutissent à la même confirmation :

- **Double-cliquez dessus** dans le Finder. Peach Commander s'ouvre et vous demande.
- **Appuyez sur Entrée** dessus dans un panneau. Peach Commander est un gestionnaire de fichiers : c'est là que le fichier se trouve déjà, la plupart du temps.
- **Faites-le glisser sur la fenêtre des extensions** (Configuration ▸ Extensions…).
- Choisissez **Configuration ▸ Extensions… ▸ Installer…** et sélectionnez le paquet, un `.zip` contenant une extension, ou un bundle d'extension décompressé.

Avant que quoi que ce soit ne soit chargé, une boîte de dialogue indique le nom, la version, l'identifiant et le type de l'extension, ainsi que les types de fichiers qu'elle prendra en charge — une extension qui revendique `.iso`, par exemple, devient le lecteur de l'application pour ces fichiers. Rien n'est installé tant que vous n'avez pas cliqué sur **Installer**.

Si une extension portant le même identifiant est déjà installée, la boîte de dialogue le signale et affiche les deux versions : une mise à jour se lit comme une mise à jour (« 1.0.0 → 1.1.0 ») et un retour en arrière est annoncé comme tel.

## Avant d'en installer une

Une extension est un programme qui s'exécute dans Peach Commander, avec le même accès à vos fichiers que Peach Commander lui-même. Il n'y a pas de bac à sable autour. N'installez que des extensions provenant de sources auxquelles vous faites confiance, comme pour n'importe quelle autre application.

Les extensions téléchargées depuis Internet arrivent en quarantaine sous macOS. L'installation indique à macOS d'autoriser leur chargement — c'est pourquoi la boîte de dialogue le dit, et pourquoi c'est une décision que vous prenez plutôt que quelque chose qui se produit en silence.

## Retirer une extension

1. Dans la fenêtre des extensions, sélectionnez l'extension dans la liste.
2. Cliquez sur **Retirer**. Les fonctions intégrées ne sont pas affectées ; seule l'extension sélectionnée est retirée.

Une extension livrée avec l'application ne peut pas être supprimée : « Retirer » la désactive à la place.

## Remarques

- La liste indique la version, le type et la version d'interface de chaque extension à côté de son nom et de son emplacement, pour que vous puissiez vérifier ce qui est installé.
- Si une extension nécessite une version de Peach Commander plus récente que la vôtre, elle est refusée avec un message qui le dit, plutôt que d'échouer obscurément. L'inverse est vrai aussi : une extension conçue pour une interface plus ancienne continue de fonctionner tant que cette interface est prise en charge.
- Certaines extensions n'ajoutent leurs colonnes, entrées de menu ou emplacements de panneau que lorsqu'elles sont activées. Si une fonctionnalité attendue manque, vérifiez ici que son extension est bien activée.
- Écrire ou publier votre propre extension est traité dans la documentation destinée aux développeurs, pas ici.
