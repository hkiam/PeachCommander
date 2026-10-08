---
title: Clavier et raccourcis
slug: keyboard-shortcuts
section: Personnalisation
order: 112
related: [keyboard-shortcuts-reference, settings, macros]
---

Peach Commander est conçu pour être piloté au clavier. Il est livré avec deux schémas de raccourcis prêts à l'emploi et vous permet de réassigner n'importe quelle commande aux touches que vous préférez. Si vous venez d'un gestionnaire de fichiers classique à deux panneaux, vous pouvez conserver les touches que vous connaissez déjà ; si vous préférez les combinaisons Mac familières, basculez vers le schéma macOS en un clic. Un explorateur de commandes avec recherche vous permet de découvrir tout ce que l'application peut faire et d'exécuter n'importe quelle commande par son nom.

## Changer de schéma de clavier

1. Ouvrez les **Réglages** (Cmd+, ou **Configuration > Réglages…**) et choisissez la page **Clavier**.
2. Choisissez un schéma dans le menu **Schéma** :
   - **Total Commander (classique)** (par défaut) conserve les touches traditionnelles, avec des combinaisons à base de Ctrl telles que Ctrl+R pour actualiser un panneau.
   - **macOS** mappe les mêmes actions sur des touches Mac familières là où c'est pertinent, par exemple Cmd+C pour copier des fichiers et Cmd+F pour rechercher.
3. Le changement prend effet immédiatement dans les menus et la barre de raccourcis. **Modifier les raccourcis…** se trouve juste en dessous, car les réassignations individuelles se superposent au schéma que vous avez choisi.

## Personnaliser les raccourcis

1. Choisissez **Configuration > Modifier les raccourcis…**, ou cliquez sur **Modifier les raccourcis…** dans la page Clavier des Réglages.
2. Trouvez une commande à l'aide du champ de recherche, puis sélectionnez sa ligne.
3. Cliquez sur **Enregistrer…** et appuyez sur la combinaison de touches voulue. Elle est assignée immédiatement.
4. Si cette combinaison était déjà utilisée par une autre commande, un avis indique à quelle commande elle a été prise.
5. Utilisez **Effacer** pour retirer le raccourci d'une commande, ou **Rétablir les valeurs par défaut** pour abandonner toutes vos modifications et revenir aux touches d'origine du schéma.

![L'éditeur de raccourcis clavier listant les commandes avec leurs touches assignées](screenshots/keys-editor.png)
*(Figure : recherchez une commande, puis utilisez Enregistrer, Effacer ou Rétablir les valeurs par défaut pour changer son raccourci.)*

## Parcourir toutes les commandes

1. Choisissez **Configuration > Explorateur de commandes…**.
2. Saisissez dans le champ de recherche pour filtrer par nom, catégorie ou description.
3. Double-cliquez sur une commande, ou sélectionnez-la et cliquez sur **Exécuter**, pour l'appliquer au panneau actif.

![L'explorateur de commandes montrant une liste de commandes avec recherche](screenshots/command-browser.png)
*(Figure : toutes les commandes dans une seule liste consultable, avec une brève description de chacune.)*

## Raccourcis

| Action | Chemin de menu |
|---|---|
| Choisir un schéma | Réglages > Clavier > Schéma |
| Modifier les raccourcis | Configuration > Modifier les raccourcis… |
| Parcourir toutes les commandes | Configuration > Explorateur de commandes… |
| Actualiser le panneau actif | F2 (aussi Ctrl+R) |

## Remarques

- Vos raccourcis personnalisés sont enregistrés automatiquement et superposés au schéma actif. Changer de schéma conserve vos remplacements personnels.
- Les commandes non disponibles dans le contexte actuel apparaissent grisées à la fois dans l'éditeur de raccourcis et dans l'explorateur de commandes.
- Pour utiliser les touches de fonction (F1–F12) directement, activez **Utiliser les touches F1, F2, etc. comme des touches de fonction standard** dans Réglages Système > Clavier. Sinon, maintenez la touche **Fn** avec la touche de fonction.
