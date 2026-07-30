---
title: Carte du disque
slug: disk-map
section: Extensions
order: 121
related: [plugins, deleting-files, settings]
---

Carte du disque est une extension intégrée qui montre, d'un coup d'œil, ce qui occupe de l'espace dans un dossier ou sur tout un volume. Elle analyse le dossier que vous choisissez et dessine chaque élément dimensionné en proportion de l'espace qu'il occupe réellement sur le disque, de sorte que les plus gros gouffres d'espace ressortent immédiatement. Vous pouvez explorer les dossiers, voir comment votre analyse se réconcilie avec l'espace libre, purgeable et masqué du volume, et faire le ménage directement depuis la carte.

## Lancer une analyse

1. Dans le panneau actif, allez au dossier (ou au volume) que vous voulez mesurer.
2. Choisissez **Commandes ▸ Carte du disque : analyser le dossier actuel**.
3. La vue Carte du disque s'ouvre à droite et analyse en arrière-plan, affichant un décompte en cours des éléments et des octets. Les gros dossiers se terminent en quelques secondes — l'analyse lit les métadonnées de répertoire en masse et travaille sur plusieurs cœurs de processeur.

![La Carte du disque montrant une treemap carrée d'un dossier, une barre de volume, une liste des plus gros fichiers et une légende par catégorie](screenshots/disk-map.png)
*(Figure : la vue treemap, colorée par catégorie de fichier, avec la barre de volume en haut et la liste des plus gros fichiers à droite.)*

## Lire la carte

- Chaque bloc (treemap) ou segment d'anneau (sunburst) est dimensionné selon la **taille réelle sur le disque** de l'élément, de sorte que l'image correspond à ce que rapportent le Finder et le système.
- Les blocs sont **colorés par type de fichier** — vidéo, images, audio, documents, code, archives, apps, images disque — avec une légende en bas. Vous pouvez passer à une **carte de chaleur** par taille dans les réglages.
- **Cliquez sur un dossier** pour l'explorer ; le fil d'Ariane en haut montre où vous êtes, et le bouton **◂** remonte d'un niveau.
- Survolez n'importe quel bloc pour voir son chemin complet, sa taille et son nombre d'éléments.

## Deux vues : treemap et sunburst

Carte du disque propose deux visualisations, et vous pouvez basculer entre elles avec le bouton **◎ / ▦** dans l'en-tête ou sur la page des réglages :

- **Treemap** — rectangles imbriqués, la plus dense pour repérer le plus gros fichier isolé.
- **Sunburst** — anneaux concentriques (un par profondeur de dossier) autour du dossier courant, idéale pour voir comment l'espace se répartit dans une arborescence profonde.

![La vue sunburst de la Carte du disque montrant des anneaux concentriques pour la profondeur des dossiers](screenshots/disk-map-sunburst.png)
*(Figure : la vue sunburst — le disque intérieur est le dossier courant et chaque anneau est un niveau plus profond.)*

## La barre de volume

La barre en haut réconcilie votre analyse avec tout le volume :

- **Analysé / Ce dossier** — combien occupe le dossier analysé.
- **Masqué** (à la racine du volume) ou **Reste du volume** (pour un sous-dossier) — tout ce qui n'est pas dans cette analyse, y compris les dossiers protégés par le système, les autres utilisateurs et les instantanés.
- **Purgeable** — l'espace que macOS peut récupérer automatiquement, surtout les instantanés Time Machine locaux et les caches.
- **Libre** — l'espace disponible dès maintenant.

Lorsque le volume a des instantanés locaux, la barre affiche un élément **· N instantanés (ⓘ)** ; cliquez dessus pour une liste en lecture seule, avec une astuce pour les gérer dans Utilitaire de disque ou Time Machine. Carte du disque ne supprime jamais elle-même les instantanés.

## Les plus gros fichiers

Activez **Afficher la liste des plus gros fichiers** pour voir les plus gros fichiers du dossier courant classés par taille, chacun avec une pastille de couleur pour sa catégorie. Cliquez sur l'un d'eux pour le mettre en évidence sur la carte.

## Faire le ménage depuis la carte

Cliquez droit sur n'importe quel bloc pour des actions :

- **Ouvrir dans le panneau gauche** / **Ouvrir dans le panneau droit** — révéler l'élément dans un panneau de fichiers.
- **Révéler dans le Finder**.
- **Placer dans la corbeille** — supprimer juste cet élément ; la carte se met à jour sans réanalyse complète.

Pour retirer plusieurs éléments à la fois, utilisez le **collecteur** : clic droit ▸ **Marquer pour le collecteur** sur chaque élément, puis cliquez sur le bouton **🗑 N** de l'en-tête pour placer tout ce que vous avez marqué dans la corbeille en une seule étape confirmée.

## Réglages

Carte du disque ajoute sa propre page à la fenêtre des Réglages (**Configuration ▸ Réglages ▸ Carte du disque**) :

- **Style de graphique** — treemap ou sunburst.
- **Codage couleur** — par type de fichier (catégorie) ou par taille (carte de chaleur).
- **Rester sur le volume de départ** — ne pas traverser vers d'autres disques montés.
- **Afficher la barre de volume** et **Afficher la liste des plus gros fichiers**.

Les changements s'appliquent immédiatement à une Carte du disque ouverte.

## Remarques

- Carte du disque mesure la taille **allouée** (sur le disque) et ne compte les fichiers **à liens matériels** qu'une seule fois, de sorte que ses totaux s'alignent sur l'espace utilisé du volume plutôt que de le surestimer.
- Par défaut, l'analyse reste sur le volume de départ, elle ne s'aventure donc pas dans d'autres disques montés ou partages réseau.
