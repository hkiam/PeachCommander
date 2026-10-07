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
précédente. **Fetch**, **Tirer** et **Pousser** sont juste à côté, là où la validation a lieu de toute façon ; les trois
affichent leur progression et peuvent être annulés.

La validation porte sur l’*index*, pas sur `git commit -a` : ce que vous avez indexé est ce qui est validé.

## L’historique dans le panneau

Sous ses boutons, le panneau affiche l’historique de toutes les branches, branches distantes et étiquettes sous forme de graphe dessiné, la copie de travail en première ligne. La zone du dessous suit la sélection :

![Le panneau Git avec le graphe des branches, le commit de fusion sélectionné et son fichier modifié avec le diff en ligne](screenshots/git-panel.png)

- **Modifications locales** montre les fichiers indexés, modifiés et non suivis ainsi que la zone de commit décrite plus haut.
- Un commit montre soit **Commit** — auteur, committer, date, hash, parents, réfs, signature et message complet — soit **Modifications**.
- **Modifications** liste les fichiers touchés en arbre et le diff du fichier choisi avec numéros de ligne ; un double-clic ouvre la fenêtre de comparaison.
- Le menu contextuel copie le hash ou le sujet, annule, fait un cherry-pick, ouvre le commit sur le web et limite la liste à **Uniquement la branche actuelle**.
- Depuis ce même menu, un commit peut être extrait, recevoir une nouvelle branche ou étiquette, être fusionné dans la branche actuelle, servir de base pour rebaser ou réinitialiser la branche actuelle, ou ouvrir un rebase interactif.
- Le champ de recherche au-dessus de la liste parcourt tout l’historique — message, nom et e-mail de l’auteur, ou un hash et ses premiers caractères — et liste les résultats sans le graphe.

## Plus dans le panneau et dans le menu Git

La copie de travail, l’historique et le menu **Commandes ▸ Git** offrent davantage que la validation :

- Un fichier indexé ou modifié sélectionné montre son diff sous la liste ; des lignes sélectionnées ou un bloc entier s’indexent, se désindexent ou s’abandonnent depuis son menu contextuel.
- Le champ de commit accepte plusieurs lignes — un sujet, une ligne vide, un corps —, valide avec **Cmd+Retour** et compte les caractères du sujet ; le bouton de menu à côté garde vos derniers messages de commit.
- **Afficher dans le panneau de gauche** et **Afficher dans le panneau de droite** amènent un panneau de fichiers sur un fichier de la liste ou des modifications d’un commit, sans que le panneau Git bouge ; les fichiers stockés par Git LFS sont marqués **LFS**.
- Les remisages apparaissent dans l’historique sous forme de petits carrés au-dessus du commit sur lequel ils ont été faits, avec **Appliquer le remisage**, **Appliquer et retirer le remisage** et **Supprimer le remisage…** dans leur menu contextuel.
- **Reflog…** liste chaque déplacement de HEAD ; un commit perdu par un reset ou une branche supprimée revient avec **Nouvelle branche ici…**.
- **Réglages du dépôt…** ajoute, renomme, redirige et supprime des dépôts distants, ajoute, met à jour et supprime des sous-modules, gère les worktrees et donne à ce seul dépôt un nom et une adresse e-mail pour les commits.
- **Créer un dépôt ici…** et **Cloner un dépôt…** agissent dans le dossier du panneau actif, et l’horloge à côté du titre du panneau ramène à un dépôt récent.

## Quand git s’arrête, et les réglages

- **Push** définit la branche amont lors du premier envoi d’une branche. Si le dépôt distant a des commits absents de cette branche, il propose **Tirer, puis pousser** ou **Forcer l’envoi**, toujours avec un bail qui refuse si quelqu’un a poussé depuis votre dernier fetch ; **Forcer l’envoi (avec bail)…** figure aussi dans le menu contextuel de **Push**.
- Si **Pull** constate que la branche et sa branche amont ont divergé, il demande s’il faut fusionner ou rebaser au lieu de s’arrêter sur le message de git.
- Une fusion, un cherry-pick, un revert, un rebase ou une série de patchs arrêtés sur un conflit affichent au-dessus de l’historique un bandeau avec **Continuer** et **Abandonner…** ; un commit de fusion est annulé ou repris par rapport à son premier parent.
- Sélectionnez deux commits pour les comparer, ou plusieurs pour les reprendre d’un coup. **Comparer avec la copie de travail** et **Enregistrer comme patch…** sont dans le menu de l’historique, **Appliquer des patchs…** dans le menu Git.
- Le champ de recherche accepte aussi des filtres — `author:name`, `path:folder/`, `since:"2 weeks ago"`, `until:2026-10-01` — seuls ou avec des mots.
- **Bisect : marquer comme mauvais** et **Bisect : marquer comme bon** dans le menu de l’historique lancent un bisect ; le bandeau propose alors **Bon**, **Mauvais**, **Ignorer** et **Terminer le bisect** jusqu’à ce que git nomme le premier mauvais commit.
- Remiser des fichiers choisis ou toutes les modifications demande un message et s’il faut inclure les fichiers non suivis ou garder l’index. Les fichiers dans Git LFS peuvent être verrouillés et déverrouillés, et leur type de fichier suivi.
- Dans la liste des branches, une branche peut être renommée (**Renommer…**), reliée à une branche amont (**Définir la branche amont…**) ou supprimée sur son serveur (**Supprimer sur le dépôt distant…**).
- **Réglages ▸ Git** définit le programme git, vos nom et adresse e-mail globaux, le fonctionnement de **Pull**, le fetch en arrière-plan, ce que montre l’historique et l’aspect de ses dates, la signature, le sign-off et les hooks des commits, ainsi que les espaces et les lignes de contexte des diffs. Les auteurs portent des initiales colorées dans l’historique.

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

- L’extension utilise le Git du système, à `/usr/bin/git`, ou le programme choisi dans **Réglages ▸ Git**. Si Git n’est pas installé, les commandes signalent que Git n’est pas disponible. (Les Command Line Tools de Xcode le fournissent.)
- L’état du dépôt est lu une fois par dossier puis mis en cache, pour que le défilement d’un gros dépôt reste
  rapide ; le cache se rafraîchit après toute commande qui modifie l’arbre, et suit une validation faite hors
  de l’application.
- Les copies de travail liées et les sous-modules sont pris en charge : un fichier dans un sous-module montre
  l’état et la branche *du sous-module*, pas ceux du dépôt parent.
- Chaque liste a un menu contextuel, **Retour** lance son action principale et **Cmd+R** recharge la fenêtre.
- Git LFS, `gpg` pour les commits signés et les assistants d’identification sont trouvés dans les dossiers de Homebrew et MacPorts, même si l’app a été ouverte depuis le Finder.
