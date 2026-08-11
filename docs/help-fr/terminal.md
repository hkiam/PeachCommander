---
title: Le terminal intégré
slug: terminal
section: Plugins
order: 127
related: [plugins, opening-files, macos-integration, keyboard-shortcuts]
---

Peach Commander peut faire tourner un vrai shell dans sa propre fenêtre, dans une bande en bas appelée le dock. C’est votre shell de connexion — celui que désigne `$SHELL`, ou `/bin/zsh` s’il n’est pas utilisable — donc votre `PATH`, vos alias et vos fonctions sont tous là, exactement comme dans Terminal.

Ce n’est pas la même chose que **Ouvrir un terminal ici**, qui lance l’app Terminal d’Apple dans le dossier courant et vous laisse avec deux fenêtres. Celui-ci reste là où sont vos fichiers, et il les connaît.

C’est une extension : si vous n’en voulez pas, désactivez-la ou supprimez-la dans **Configuration ▸ Extensions…**, et le dock s’en va avec elle.

## L’ouvrir et s’y déplacer

Appuyez sur **Ctrl** avec la touche à gauche du « 1 » pour déplacer le clavier entre le panneau de fichiers et le terminal. Ce raccourci est lié à la *position* de la touche, pas à son caractère : c’est donc la même touche physique quel que soit le nom que lui donne votre disposition : l’accent grave sur un clavier US, `^` sur un allemand, `@` sur un français.

Tout le reste se trouve dans le menu **Terminal** :

| Action | Ce qu’elle fait |
| --- | --- |
| Basculer entre le panneau et le terminal | Déplace le focus clavier, sans rien changer d’autre |
| Nouvel onglet de terminal | Un autre shell, dans le même dossier |
| Fermer l'onglet de terminal | Le ferme — en demandant d’abord si quelque chose y tourne encore |
| Diviser le terminal | Deux shells côte à côte dans le même onglet |
| Aller au dossier du panneau | Fait un `cd` du terminal vers l’emplacement du panneau actif |
| Insérer les noms de fichiers sélectionnés | Tape les noms sélectionnés à l’invite, entre guillemets |
| Exécuter la ligne de commande dans le terminal | Envoie ce que vous avez tapé sur la ligne de commande au shell au lieu de l’exécuter de façon invisible |

Tant que le terminal a le focus, les **touches de fonction lui reviennent**, pas au panneau de fichiers — F5 dans un éditeur de texte lancé dans le terminal doit atteindre l’éditeur. La barre des touches de fonction le dit, plutôt que d’afficher des touches qui ne déclencheront rien.

## Le pont vers le panneau

**Cmd-cliquez un chemin** dans la sortie du terminal et le panneau s’y rend. Un fichier issu de `ls`, un chemin dans une erreur de compilation, un nom dans `git status` — un clic et vous le regardez.

Cela n’agit que si le mot sous le pointeur correspond vraiment à quelque chose qui existe. Un Cmd-clic sur du texte ordinaire ne fait rien plutôt que de naviguer au hasard, et un clic simple sélectionne toujours le texte comme avant.

**Déposez des fichiers sur le terminal** et leurs chemins arrivent à l’invite, entre guillemets, prêts pour une commande que vous êtes en train de taper.

## Laisser le panneau suivre le shell

Désactivé par défaut : quand vous faites un `cd` dans le terminal, le panneau reste où il est. Activez **Laisser le panneau actif suivre le terminal** sur la page de réglages du terminal et il suivra.

Cela demande l’aide de votre shell, car un shell n’annonce pas où il est allé. La page de réglages affiche un court extrait à ajouter à votre `~/.zshrc` et un bouton pour le copier ; il fait signaler à zsh son dossier de travail (la séquence d’échappement OSC 7) avant chaque invite. Sans cet extrait, le réglage est actif et rien ne suit — c’est pourquoi l’extrait est juste à côté.

## Recherche et historique

**Cmd+F** cherche dans ce que le terminal a affiché.

Un terminal conserve **5 000 lignes** d’historique par défaut — de quoi remonter une compilation. Modifiable sur la page de réglages. Les valeurs très grandes sont bornées, car un historique de cinquante millions de lignes est un problème de mémoire dont la cause est impossible à voir de l’extérieur.

## Où il se place

Le terminal s’ouvre dans le dock en bas, parce que c’est la forme qu’il lui faut : un shell a besoin de largeur, et le panneau latéral, à ses 300 points par défaut, tient environ 44 colonnes là où le bas d’une fenêtre de 1200 points en tient 176.

Vous pouvez tout de même le déplacer. Faites-le glisser vers le panneau latéral si cela vous convient mieux, ou utilisez les commandes de placement décrites dans [Extensions](plugins.md) ; le déplacer **réattache le même shell** au lieu d’en démarrer un nouveau, donc ce qui tourne continue de tourner.

Les onglets reviennent au redémarrage de l’app, dans les dossiers où ils étaient. Ce qui y *tournait*, non — un redémarrage met fin à ces processus, comme dans n’importe quel terminal.

## En quittant

Fermer l’app ferme les shells. Ce qui y tourne encore est arrêté, comme fermer une fenêtre de Terminal arrête ce qu’elle contient. C’est pourquoi fermer un onglet où quelque chose tourne demande d’abord confirmation.
