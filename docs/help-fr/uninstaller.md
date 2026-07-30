---
title: Uninstaller
slug: uninstaller
section: Extensions
order: 126
related: [plugins, deleting-files]
---

Faire glisser une application vers la Corbeille laisse ses fichiers de support, caches, préférences et conteneurs éparpillés dans vos dossiers Bibliothèque. L'extension Uninstaller retire une application **et** ces restes : elle trouve tout ce que l'application a laissé derrière elle, vous en montre la liste avec une taille pour chacun, et place le tout dans la Corbeille une fois que vous confirmez. C'est une extension, vous pouvez donc la désactiver ou la retirer dans **Configuration ▸ Extensions…**.

## Désinstaller une application sous le curseur

1. Placez le curseur sur une application (`.app`) dans un panneau.
2. Choisissez **Fichier ▸ Désinstaller l'application…**, ou clic droit ▸ **Désinstaller l'application…**, ou appuyez sur **Cmd+Maj+U**.
3. La fenêtre de revue s'ouvre, listant l'application ainsi que chaque fichier apparenté qu'elle a trouvé, chacun étiqueté avec sa catégorie, son chemin et sa taille.
4. Décochez tout ce que vous voulez conserver, puis cliquez sur **Placer dans la Corbeille** (ou **Supprimer définitivement**).

![La fenêtre de revue de désinstallation listant les fichiers restants d'une application avec des cases à cocher et des tailles](screenshots/uninstaller.png)
*(Figure : passez en revue exactement ce qui sera retiré avant que quoi que ce soit ne soit supprimé.)*

## Parcourir toutes les applications installées

Choisissez **Commandes ▸ Désinstaller l'application…** pour ouvrir une liste consultable des applications installées sur votre Mac, avec le nom, la taille et la date d'installation de chacune. Sélectionnez-en une (ou plusieurs), cliquez sur **Désinstaller…**, et vous arrivez dans la même fenêtre de revue. Vous pouvez filtrer la liste en saisissant dans le champ de recherche.

## Trouver les fichiers restants

Choisissez **Commandes ▸ Trouver les fichiers restants…** pour rechercher les fichiers de support, caches et préférences appartenant à des applications que vous avez **déjà** supprimées. Passez-les en revue de la même manière et faites le ménage. Si rien n'est trouvé, l'extension vous le signale.

## Quelle profondeur d'analyse

La fenêtre de revue dispose d'un contrôle de confiance :

- **Précis** — fichiers ancrés à l'identifiant de paquet de l'application. Confiance élevée ; présélectionnés.
- **Étendu** — ajoute les fichiers correspondant par nom ; laissés décochés pour que vous puissiez décider.
- **Approfondi** — Étendu plus un balayage Spotlight pour tout ce qui mentionne l'application ; également laissé décoché.

## Remarques

- Rien n'est supprimé directement par l'extension — les éléments passent par la Corbeille de l'application ou la suppression définitive, exactement comme toute autre opération sur fichiers. Retirer des fichiers dans `/Library` ou `/var` peut nécessiter un mot de passe administrateur.
- Avant de retirer, l'extension quitte l'application en cours d'exécution et décharge ses éléments d'arrière-plan (launchd), puis propose de nettoyer les dossiers de fournisseur désormais vides.
- Si l'application a été installée avec **Homebrew**, l'extension vous avertit et suggère `brew uninstall --cask` pour que Homebrew reste synchronisé. Les applications de l'App Store sont également signalées.
- Les correspondances Étendu et Approfondi sont de confiance plus faible par conception et commencent décochées — passez-les en revue avant de retirer. Certains éléments d'arrière-plan installés via l'API moderne des éléments d'ouverture ne peuvent pas être retirés ici.
