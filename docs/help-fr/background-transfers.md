---
title: Transferts en arrière-plan
slug: background-transfers
section: Fichiers et dossiers
order: 32
related: [copying-files, downloading-from-url]
---

Les copies, déplacements, suppressions et téléchargements volumineux n'ont pas à interrompre votre travail. Peach Commander peut les exécuter en arrière-plan et les rassembler en un seul endroit : le gestionnaire de transferts en arrière-plan. De là, vous suivez la progression et la vitesse de transfert de chaque tâche, la mettez en pause ou la reprenez, l'annulez, ou mettez des tâches en file d'attente pour les démarrer plus tard. Comme une tâche en arrière-plan s'exécute de manière autonome, elle ne vous empêche jamais de naviguer, d'ouvrir des fichiers ou de lancer le transfert suivant.

## Marche à suivre

1. Lancez une copie, un déplacement, une suppression ou un téléchargement et choisissez de l'exécuter en arrière-plan. La tâche apparaît dans le gestionnaire de transferts en arrière-plan.
2. Ouvrez le gestionnaire à tout moment depuis **Commandes ▸ Gestionnaire de transferts en arrière-plan…** (ou appuyez sur Cmd+Shift+B).
3. Chaque tâche affiche un titre, une barre de progression et une ligne en direct indiquant les fichiers terminés, les octets transférés et la vitesse actuelle.
4. Utilisez les boutons de chaque tâche pour **Mettre en pause**, **Reprendre** ou **Annuler** pendant qu'une tâche est en cours.
5. Pour les tâches que vous avez ajoutées mais pas encore démarrées (tâches en attente), cliquez sur **Démarrer** sur la tâche, ou sur **Tout démarrer** pour lancer d'un coup toute la liste d'attente.
6. Lorsque tout ce qui vous intéresse est terminé, cliquez sur **Effacer les tâches terminées** pour ranger la liste.

![Le gestionnaire de transferts en arrière-plan répertoriant les tâches actives et en attente avec des barres de progression et des boutons Mettre en pause, Reprendre et Annuler.](screenshots/transfer-manager.png)

*Chaque transfert est une ligne que vous pouvez mettre en pause, reprendre ou annuler indépendamment.*

## Raccourcis

| Action | Raccourci |
| --- | --- |
| Ouvrir le gestionnaire de transferts en arrière-plan | Cmd+Shift+B |

## Astuces

- **Limitez la vitesse.** Pour éviter qu'un gros transfert ne sature votre connexion ou votre disque, définissez une limite de vitesse dans la boîte de dialogue de copie avant de lancer la tâche. Le gestionnaire affiche alors le débit bridé en direct.
- **Mettez en file d'attente pour plus tard.** Les tâches en attente restent dans la liste sans s'exécuter jusqu'à ce que vous appuyiez sur Démarrer (ou Tout démarrer) : vous pouvez ainsi préparer plusieurs transferts et les lancer ensemble.
- **Exécutez-en plusieurs à la fois.** Les tâches s'exécutent indépendamment : vous pouvez donc en mettre une en pause pendant qu'une autre continue.

## Remarques

Comme une tâche en arrière-plan s'exécute sans que vous la surveilliez, elle ne peut pas s'arrêter pour poser des questions. Si un fichier existe déjà à la destination, la tâche en arrière-plan l'écrase ; si un élément individuel ne peut pas être transféré, cet élément est ignoré et la tâche continue. Une fois la tâche terminée, tous les éléments ignorés sont regroupés dans un journal d'erreurs afin que vous puissiez examiner exactement ce qui n'a pas fonctionné.
