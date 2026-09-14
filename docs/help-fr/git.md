---
title: Git
slug: git
section: Extensions
order: 123
related: [plugins, view-modes-and-sorting]
---

L’extension Git fait apparaître l’état d’un dépôt Git directement dans le panneau de fichiers — pas
d’application à part, pas de terminal. Elle ajoute deux colonnes, un sous-menu **Git**, un panneau ancré pour
indexer et valider, et des fenêtres pour l’historique, le blâme, les branches, les conflits et le rebasage.
Elle pilote le `git` déjà installé sur votre Mac. C’est une extension : vous pouvez la désactiver ou la
supprimer dans **Configuration ▸ Extensions…**.

## Ce qu’elle ajoute

- **Deux colonnes de liste** — *État Git* et *Branche*. Chaque fichier affiche une icône et un mot d’état
  bref (Modifié, Ajouté, Supprimé, Non suivi, Renommé, Copié, Conflit, Ignoré, Type changé), avec *(indexé)*
  lorsque la modification est déjà dans l’index ; la colonne *Branche* indique la branche sur laquelle se
  trouve le dépôt de ce fichier. Activez les colonnes dans **Configuration ▸ Colonnes…** (voir
  [Modes d’affichage et tri](view-modes-and-sorting.md)).
- **Un menu Git** — sous **Commandes ▸ Git**, et dans le menu contextuel d’un fichier.

![La fenêtre État Git montrant la branche courante et les fichiers modifiés du dépôt](screenshots/git-status.png)
*(Figure : État Git indique la branche et chaque modification de la copie de travail.)*

## Le panneau : indexer, valider, synchroniser

**Commandes ▸ Git ▸ Panneau** ancre une vue qui groupe la copie de travail en *indexé*, *modifié* et *non
suivi*. Sélectionnez des fichiers et utilisez **Indexer**, **Désindexer** ou **Abandonner…**, saisissez un
message et appuyez sur **Valider** — avec **Amender** pour replier la modification dans la validation
précédente. **Tirer** et **Pousser** sont juste à côté, là où la validation a lieu de toute façon ; les deux
affichent leur progression et peuvent être annulés.

La validation porte sur l’*index*, pas sur `git commit -a` : ce que vous avez indexé est ce qui est validé.

## Historique, blâme et le web

- **Historique…** liste les validations avec un graphe en couloirs, les références qui pointent sur chacune
  (`● main`, `↗ origin/main`, `⚑ v1.0`), et les fichiers que chaque validation a touchés. Entrée ou un
  double-clic ouvre la version de ce fichier face à son parent dans la fenêtre de comparaison. **Annuler la
  validation** et **Picorer** y sont, et tous deux refusent d’emblée si la copie de travail n’est pas propre.
- **Historique du fichier…** est la même fenêtre pour un seul fichier.
- **Blâme (liste)…** montre chaque ligne avec sa validation, son auteur et sa date. **Blâme dans l’éditeur**
  met la même information dans la gouttière de l’éditeur, à côté des numéros de ligne : survolez une ligne
  pour le message de la validation, cliquez pour l’ouvrir face à son parent.
- **Ouvrir sur le web** ouvre le fichier, la validation ou la branche sur GitHub, GitLab, Bitbucket ou Azure
  DevOps, à partir de l’URL du dépôt distant — pas de compte, pas de jeton. Pour un hôte dont elle ne connaît
  pas la forme des liens, elle propose la page du dépôt plutôt que de deviner.

## Branches, remises et étiquettes

**Branches, remises et étiquettes…** liste les trois. Changer de branche, en créer, en fusionner ou en
supprimer une ; pousser, dépiler ou jeter une remise ; créer, supprimer ou pousser une étiquette, ou basculer
dessus — une étiquette n’est pas une branche, aussi est-il dit d’emblée que HEAD finira détaché. Récupérer,
Tirer et Pousser sont dans la même fenêtre et peuvent être annulés en cours.

Pousser une étiquette est une action distincte à dessein : `git push` n’emporte pas les étiquettes.

## Conflits

**Résoudre le conflit…** liste les régions en conflit du fichier sous le curseur et prend une décision pour
chacune : *les nôtres*, *les leurs*, *les deux*, ou laisser ouvert. Puis **Écrire le fichier** ou **Écrire et
indexer**. Elle refuse d’indexer tant qu’une région reste ouverte — Git validerait volontiers des marques
`<<<<<<<` — et elle refuse de toucher un fichier dont elle ne sait pas lire les marques plutôt que de les
deviner. Pour une région qui demande d’entrelacer les deux côtés à la main, **Ouvrir dans l’éditeur** est à
un bouton.

## Rebasage

**Rebaser…** liste les validations en avance sur l’amont — celles que personne d’autre n’a encore — et vous
laisse les écraser, les corriger, les abandonner, les réordonner ou les reformuler avant de réécrire la
branche. Si un rebasage s’arrête sur un conflit, la même fenêtre devient **Continuer** / **Sauter la
validation** / **Abandonner le rebasage**, de sorte qu’un rebasage à moitié fait n’a pas à être terminé dans
un terminal.

## Ignorer des fichiers, et les identifiants

- **Ignorer ce fichier…**, **Ignorer ce type de fichier…** et **Ignorer ce dossier…** ajoutent le motif qui
  convient à `.gitignore` — ancré là où il doit l’être, pour qu’ignorer *ce* dossier `build` n’ignore pas
  tous les dossiers nommés `build`.
- **Identifiants…** indique comment ce dépôt s’authentifie : SSH ou HTTPS, si un assistant d’identifiants est
  configuré, si un agent SSH tourne et détient une clé. Là où cela aide, elle propose une seule action —
  laisser Git conserver les identifiants dans le trousseau de macOS. L’extension ne demande jamais de phrase
  secrète, ne l’affiche pas et ne la conserve pas.

## Remarques

- L’extension utilise le Git du système, à `/usr/bin/git`. Si Git n’est pas installé, les commandes signalent
  qu’il n’est pas disponible. (Les Xcode Command Line Tools le fournissent.)
- L’état du dépôt est lu une fois par dossier puis mis en cache, pour que le défilement d’un gros dépôt reste
  rapide ; le cache se rafraîchit après toute commande qui modifie l’arbre, et suit une validation faite hors
  de l’application.
- Les copies de travail liées et les sous-modules sont pris en charge : un fichier dans un sous-module montre
  l’état et la branche *du sous-module*, pas ceux du dépôt parent.
- Chaque liste a un menu contextuel, **Retour** lance son action principale et **Cmd+R** recharge la fenêtre.
