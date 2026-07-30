---
title: Clavier et raccourcis
slug: keyboard-shortcuts
section: Personnalisation
order: 112
related: [keyboard-shortcuts-reference, settings]
---

Peach Commander est conçu pour être piloté au clavier. Il est livré avec deux schémas de raccourcis prêts à l'emploi et vous permet de réassigner n'importe quelle commande aux touches que vous préférez. Si vous venez d'un gestionnaire de fichiers classique à deux panneaux, vous pouvez conserver les touches que vous connaissez déjà ; si vous préférez les combinaisons Mac familières, basculez vers le schéma macOS en un clic. Un navigateur de commandes avec recherche vous permet de découvrir tout ce que l'application peut faire et d'exécuter n'importe quelle commande par son nom.

## Changer de schéma de clavier

1. Ouvrez le menu **Configuration**.
2. Choisissez **Schéma de clavier**, puis sélectionnez-en un :
   - **TC Classic** (par défaut) conserve les touches traditionnelles, avec des combinaisons à base de Ctrl telles que Ctrl+R pour actualiser un panneau.
   - **macOS Native** mappe les mêmes actions sur des touches Mac familières là où c'est pertinent, par exemple Cmd+C pour copier des fichiers et Cmd+F pour rechercher.
3. Une coche indique le schéma actif. Le changement prend effet immédiatement dans les menus et la barre de raccourcis.

## Personnaliser les raccourcis

1. Choisissez **Configuration > Raccourcis clavier…**.
2. Trouvez une commande à l'aide du champ de recherche, puis sélectionnez sa ligne.
3. Cliquez sur **Enregistrer…** et appuyez sur la combinaison de touches voulue. Elle est assignée immédiatement.
4. Si cette combinaison était déjà utilisée par une autre commande, un avis indique à quelle commande elle a été prise.
5. Utilisez **Effacer** pour retirer le raccourci d'une commande, ou **Rétablir les valeurs par défaut** pour abandonner toutes vos modifications et revenir aux touches d'origine du schéma.

![L'éditeur de raccourcis clavier listant les commandes avec leurs touches assignées](screenshots/keys-editor.png)
*(Figure : recherchez une commande, puis utilisez Enregistrer, Effacer ou Rétablir les valeurs par défaut pour changer son raccourci.)*

## Parcourir toutes les commandes

1. Choisissez **Configuration > Navigateur de commandes…**.
2. Saisissez dans le champ de recherche pour filtrer par nom, catégorie ou description.
3. Double-cliquez sur une commande, ou sélectionnez-la et cliquez sur **Exécuter**, pour l'appliquer au panneau actif.

![Le navigateur de commandes montrant une liste de commandes avec recherche](screenshots/command-browser.png)
*(Figure : toutes les commandes dans une seule liste consultable, avec une brève description de chacune.)*

## Raccourcis

| Action | Chemin de menu |
|---|---|
| Choisir le schéma classique | Configuration > Schéma de clavier > TC Classic |
| Choisir le schéma Mac | Configuration > Schéma de clavier > macOS Native |
| Modifier les raccourcis | Configuration > Raccourcis clavier… |
| Parcourir toutes les commandes | Configuration > Navigateur de commandes… |
| Actualiser le panneau actif | F2 (aussi Ctrl+R) |

## Remarques

- Vos raccourcis personnalisés sont enregistrés automatiquement et superposés au schéma actif. Changer de schéma conserve vos remplacements personnels.
- Les commandes non disponibles dans le contexte actuel apparaissent grisées à la fois dans l'éditeur de raccourcis et dans le navigateur de commandes.
- Pour utiliser les touches de fonction (F1–F12) directement, activez **Utiliser les touches F1, F2, etc. comme des touches de fonction standard** dans Réglages Système > Clavier. Sinon, maintenez la touche **Fn** avec la touche de fonction.
