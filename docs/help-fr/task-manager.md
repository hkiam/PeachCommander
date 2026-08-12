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

Aux côtés des colonnes habituelles Taille (mémoire) et Date (heure de démarrage), Task Manager ajoute des colonnes de processus :

| Colonne | Signification |
| --- | --- |
| **PID** | Identifiant du processus |
| **CPU %** | Utilisation récente du processeur (nécessite un second rafraîchissement pour apparaître) |
| **Threads** | Nombre de threads |
| **État** | R en cours · S en veille · T arrêté · Z zombie · I inactif |
| **Utilisateur** | Propriétaire |
| **PPID** | Identifiant du processus parent |
| **Commande** | Ligne de commande complète |

Triez selon n'importe quelle colonne (par exemple CPU % ou Taille/mémoire) comme vous le feriez dans un dossier ordinaire.

## Examiner ou terminer un processus

- **Afficher (F3)** montre un rapport *Informations sur le processus* : nom, PID, parent, utilisateur, état, threads, mémoire, CPU, heure de démarrage, chemin de l'exécutable et ligne de commande complète.
- **Supprimer (F8)** termine le processus. La première suppression envoie une **fermeture** en douceur (SIGTERM) ; supprimer une seconde fois un processus qui tourne encore passe à une **fermeture forcée** (SIGKILL). L'extension ne cible jamais le PID 1.

## Remarques

- Les détails de base (PID, parent, utilisateur, état) sont lisibles pour chaque processus, comme `ps`. La mémoire, les threads et le CPU ne peuvent être lus que pour **vos propres** processus ; les autres processus affichent ces colonnes vides (elles nécessitent des privilèges élevés, un ajout ultérieur).
- CPU % est une variation entre deux échantillons, il reste donc vide jusqu'à ce que le panneau se rafraîchisse une seconde fois (le panneau se rafraîchit à peu près toutes les deux secondes).
- La liste est en lecture seule à l'exception de la fin d'un processus — vous ne pouvez pas y copier de fichiers.
