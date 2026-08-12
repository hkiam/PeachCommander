---
title: Task Manager
slug: task-manager
section: Extensions
order: 125
related: [plugins, viewing-files, deleting-files]
---

L'extension Task Manager transforme les processus en cours sur votre Mac en un dossier que vous pouvez parcourir. Elle apparaît comme un lecteur **TaskManager** dans la barre de lecteurs ; ouvrez-le et chaque processus est une ligne que vous pouvez trier, examiner comme un fichier, ou terminer — avec les mêmes touches que vous utilisez déjà pour les fichiers. C'est une extension, vous pouvez donc la désactiver ou la retirer dans **Configuration ▸ Extensions…**.

## L'ouvrir

1. Cliquez sur l'entrée **📊 TaskManager** dans la barre de lecteurs (elle se trouve juste après votre lecteur de démarrage).
2. Le panneau se remplit d'une ligne par processus en cours. Le nom de chaque ligne est le nom du processus suivi de son PID, par exemple `Finder (462)`.
3. Le bouton **TaskManager** reste sélectionné tant que vous y êtes, et l’onglet porte le nom du lecteur. Passez à un autre onglet puis revenez — ou quittez et rouvrez l’application — et l’onglet retrouve la liste des processus. Pour en sortir, remontez d’un niveau ou cliquez sur un autre volume dans la barre de lecteurs.

![Le Task Manager listant les processus en cours avec les colonnes PID, CPU, mémoire et commande](screenshots/task-manager.png)
*(Figure : les processus en cours affichés comme une liste de fichiers que vous pouvez trier et sur laquelle vous pouvez agir.)*

## Ce que signifie chaque colonne

À côté de la colonne Date (heure de démarrage), Task Manager ajoute des colonnes de processus. La Taille d’une ligne de processus affiche `DIR`, car un processus est un dossier que vous pouvez ouvrir (voir plus bas) : la mémoire a ses propres colonnes :

| Colonne | Signification |
| --- | --- |
| **PID** | Identifiant du processus |
| **CPU %** | Utilisation récente du processeur (nécessite un second rafraîchissement pour apparaître) |
| **Memory** | Empreinte mémoire — ce dont ce processus répond (le chiffre affiché par le Moniteur d’activité) |
| **Resident** | Taille résidente, pages partagées comprises ; renseignée pour tous les processus |
| **Threads** | Nombre de threads |
| **État** | R en cours · S en veille · T arrêté · Z zombie · I inactif, plus les suffixes ajoutés par `ps` (s = chef de session, + = premier plan, N = priorité basse) |
| **Utilisateur** | Propriétaire |
| **PPID** | Identifiant du processus parent |
| **Read** | Octets lus sur le disque depuis le démarrage du processus |
| **Written** | Octets écrits sur le disque depuis le démarrage du processus |
| **Wakeups** | Réveils par interruption depuis le démarrage du processus |
| **Signed** | Qui a signé le programme : Apple, une équipe Developer ID, ad-hoc ou non signé |
| **Commande** | Ligne de commande complète |

Triez selon n'importe quelle colonne (par exemple CPU % ou Taille/mémoire) comme vous le feriez dans un dossier ordinaire.

## Examiner ou terminer un processus

- **Afficher (F3)** montre un rapport *Informations sur le processus* : nom, PID, parent, utilisateur, état, threads, mémoire, CPU, heure de démarrage, chemin de l'exécutable et ligne de commande complète.
- **Supprimer (F8)** termine le processus. La première suppression envoie une **fermeture** en douceur (SIGTERM) ; supprimer une seconde fois un processus qui tourne encore passe à une **fermeture forcée** (SIGKILL). L'extension ne cible jamais le PID 1.

## Trouver les processus qui utilisent un fichier

Faites un clic droit sur n’importe quelle ligne et choisissez **Rechercher les processus par fichier…**, puis saisissez le chemin d’un fichier. Chaque processus qui a ce fichier ouvert est mis en évidence, et le curseur saute au premier qui peut le modifier :

- **Bleu** — le processus ne fait que lire le fichier.
- **Orange** — le processus ne fait qu’y écrire.
- **Violet** — le processus fait les deux.

Le chemin est prérempli à partir du curseur de l’autre panneau : vous pouvez donc désigner un fichier là-bas et poser la question sans rien taper. **Rechercher le processus par port…**, dans le même menu, répond à la question jumelle : quel processus écoute sur un port TCP/UDP. Choisissez **Effacer la mise en évidence du fichier** pour retirer les couleurs ; quitter la liste des processus les retire aussi.

## Ouvrir un processus pour voir ses fichiers

Appuyez sur Entrée sur un processus — ou double-cliquez dessus — et le panneau liste les fichiers que ce processus a ouverts à cet instant, comme des lignes de fichier ordinaires, avec leur taille et leur date réelles. De là :

- **Voir (F3)** ouvre le fichier lui-même.
- **Aller au fichier** l’affiche dans l’autre panneau, où vous pouvez le manipuler.
- **Afficher dans le Finder** le confie au Finder.

Seuls les fichiers ouverts comptent : une bibliothèque que le processus a simplement mappée en mémoire, et son répertoire de travail, ne sont pas des fichiers ouverts. Le processus d’un autre utilisateur affiche un dossier vide.

## Remarques

- Les informations de base (PID, parent, utilisateur, état, signature) sont lisibles pour tous les processus. L’empreinte mémoire, les threads, les E/S disque et la liste des fichiers ouverts sont lisibles pour **vos propres** processus, ce qui sur un Mac ordinaire représente la plus grande partie de la liste. Pour les processus des autres utilisateurs, le CPU et Resident sont renseignés à partir de `ps` — une moyenne sur toute la vie du processus plutôt que l’écart entre deux mesures que portent les autres lignes — et les threads et l’empreinte restent vides.
- CPU % est une variation entre deux échantillons, il reste donc vide jusqu'à ce que le panneau se rafraîchisse une seconde fois (le panneau se rafraîchit à peu près toutes les deux secondes).
- La liste est en lecture seule à l'exception de la fin d'un processus — vous ne pouvez pas y copier de fichiers.
- Les couleurs de mise en évidence suivent votre thème de couleurs : la palette Norton utilise plutôt le vert, le rouge et le magenta.
- Seuls les descripteurs que votre compte a le droit d’inspecter sont trouvés, ce qui en pratique signifie vos propres processus. Une bibliothèque qu’un processus a simplement mappée en mémoire, ou son répertoire de travail, n’est pas un descripteur ouvert et n’est pas signalé.
- La colonne **Signed** se remplit pendant les premières secondes : lire une signature prend environ une milliseconde et il y a des centaines de programmes distincts, donc quelques-uns sont lus à chaque rafraîchissement puis mémorisés. Une cellule vide signifie « pas encore lue », pas « non signé ».
- **Signed** dit qui a signé le programme, pas s’il est notarisé : vérifier une notarisation revient à hacher le programme entier, ce qui prendrait des secondes pour chacun.
- Ici, le filtre rapide (Ctrl+S) porte aussi sur les colonnes et pas seulement sur le nom, et un terme peut désigner la colonne à laquelle il s’applique : `user:root state:R` demande ce que root exécute en ce moment. Les termes sont séparés par des espaces et doivent tous correspondre ; un texte qui ne désigne aucune colonne reste une seule sous-chaîne, espaces compris.
