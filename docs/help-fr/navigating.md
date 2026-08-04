---
title: Se déplacer
slug: navigating
section: Premiers pas
order: 14
related: [interface-overview, favorites]
---

Peach Commander affiche deux dossiers côte à côte : l'essentiel de votre temps consiste donc à faire passer un panneau de dossier en dossier. Vous pouvez ouvrir des dossiers, remonter dans la hiérarchie, revenir sur vos pas, saisir un chemin directement et accéder d'un bond aux emplacements du quotidien comme le dossier de départ, le bureau et les téléchargements. Toutes les actions s'appliquent au panneau *actif* — celui dont la barre de chemin est mise en évidence.

## Ouvrir des dossiers et remonter

1. Déplacez la barre de sélection avec les touches fléchées jusqu'à ce qu'un dossier soit mis en évidence.
2. Appuyez sur **Enter** (ou double-cliquez) pour l'ouvrir. Cela permet aussi d'entrer dans les archives et d'ouvrir les fichiers avec leur application par défaut.
3. Pour remonter d'un niveau vers le dossier parent, appuyez sur **Ctrl+PageUp** (ou **Backspace**).
4. Pour accéder à la racine du disque courant, choisissez **Aller ▸ Racine**.

## Revenir en arrière et en avant

Peach Commander mémorise les dossiers que vous avez visités dans chaque panneau, tout comme un navigateur web.

- Appuyez sur **Alt+Left** pour revenir au dossier précédent, et sur **Alt+Right** pour avancer de nouveau.
- Appuyez sur **Alt+Down** pour ouvrir une liste déroulante des dossiers récents et accéder à l'un d'eux.

## Saisir un chemin ou utiliser la barre de chemin

La barre de chemin en haut de chaque panneau indique où vous vous trouvez et sert aussi à vous rendre quelque part rapidement.

![Barre de chemin éditable affichant le dossier courant sous forme de segments cliquables](screenshots/path-bar-crop.png)
*(Figure : la barre de chemin. Cliquez sur un segment pour accéder à ce dossier, ou sur le crayon pour saisir un chemin complet.)*

- Cliquez sur n'importe quel segment du chemin (par exemple le nom d'un dossier parent) pour y accéder directement.
- Cliquez sur le crayon à droite de la barre de chemin pour la transformer en champ de texte, puis saisissez ou collez n'importe quel chemin et appuyez sur Enter.
- Ou choisissez **Fichier ▸ Aller au dossier…** (**Cmd+Shift+G**) pour saisir un chemin depuis n'importe où.

## Accéder aux emplacements courants

Le menu **Aller** amène le panneau actif vers les dossiers que vous utilisez le plus :

- **Départ**, **Bureau**, **Téléchargements**, **Corbeille** et **iCloud Drive**.
- **iCloud Drive** apparaît lorsqu'il est configuré sur votre Mac.

## Changer de panneau et de lecteur

- Appuyez sur **Tab** pour déplacer le focus entre le panneau gauche et le panneau droit.
- La barre de lecteurs au-dessus de chaque panneau répertorie vos volumes montés avec leur espace libre ; cliquez sur un volume pour y basculer ce panneau.
- Appuyez sur **Ctrl+U** pour échanger les deux panneaux (leurs dossiers changent de côté) ; **Ctrl+Shift+U** les échange avec leurs onglets.
- Appuyez sur **Ctrl+=** pour pointer l'autre panneau vers le même dossier que le panneau actif (*cible = source*) — pratique juste avant une copie ou un déplacement.

## Raccourcis

| Action | Raccourci |
| --- | --- |
| Ouvrir le dossier / fichier sous le curseur | Enter |
| Aller au dossier parent | Ctrl+PageUp (ou Backspace) |
| Reculer / avancer dans l'historique | Alt+Left / Alt+Right |
| Liste déroulante de l'historique | Alt+Down |
| Aller au dossier… (saisir un chemin) | Cmd+Shift+G |
| Départ | Cmd+Shift+H |
| Bureau | Cmd+Shift+D |
| Téléchargements | Option+Cmd+L |
| Changer de panneau actif | Tab |

## Astuces

- Un panneau se tient à jour tout seul : un fichier qu’un autre programme crée, modifie ou supprime dans le dossier affiché apparaît de lui-même, votre curseur et vos marques restant où ils étaient. Désactivez-le dans **Configuration ▸ Options ▸ Affichage** si un dossier dans lequel on écrit sans cesse se rafraîchit continuellement.
- Chaque panneau conserve son propre historique : Reculer et Avancer n'agissent donc que sur le côté actif.
- Si un chemin saisi ne correspond pas à un dossier valide, la barre de chemin conserve discrètement votre dernier emplacement au lieu de naviguer.
- La Corbeille et iCloud Drive dans le menu Aller n'ont pas de raccourci par défaut, mais vous pouvez leur en attribuer un dans **Configuration ▸ Options ▸ Clavier**.
