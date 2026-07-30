---
title: Limitations connues
slug: known-limitations
section: Aide et dépannage
order: 144
related: [troubleshooting]
---

Peach Commander fait beaucoup, mais quelques fonctionnalités ont des limites honnêtes dans la version actuelle. Les connaître à l'avance évite la confusion quand quelque chose se comporte de façon inattendue. Cette page liste les contraintes actuelles et, quand c'est possible, une solution de contournement simple.

## Archives

- **Les fichiers ZIP très volumineux (ZIP64) ne peuvent pas être ouverts par le lecteur intégré.** Les archives ZIP, TAR et TAR compressées en gzip standard s'ouvrent directement comme des dossiers. Les archives ZIP64 — utilisées quand une archive contient plus d'environ 65 000 éléments ou dépasse 4 Go — sortent de ce que gère le lecteur natif, elles peuvent donc échouer à s'ouvrir ou se lister de façon incomplète.
- **Les archives ZIP chiffrées** (l'ancien ZipCrypto comme WinZip AES) sont prises en charge pour la navigation, mais le mot de passe vous sera demandé.
- D'autres formats tels que CPIO, ISO, CAB, LZH, XAR et PAX s'ouvrent via un outil auxiliaire plutôt que par le lecteur natif.

## Réseau (SFTP / SCP)

- **Changer les attributs de fichier via SFTP n'a aucun effet dans cette version.** Vous pouvez parcourir, télécharger et envoyer via SFTP/SCP, mais les demandes de changement de permissions, de propriété ou d'horodatages sur un serveur distant sont ignorées en silence. Effectuez ces changements sur le serveur lui-même, ou via un autre protocole.
- À la première connexion à un serveur SFTP, il vous sera demandé de faire confiance à sa clé d'hôte. Peach Commander la mémorise ensuite (confiance à la première utilisation).

## Télécharger depuis une URL

- La commande **Télécharger depuis une URL** (menu Réseau) utilise actuellement le raccourci Cmd+Maj+D, qui est le même que Aller > Bureau. Quand les deux sont disponibles, les menus peuvent entrer en conflit — lancez le téléchargement directement depuis le menu Réseau pour être sûr.

## Actualisation des dossiers

- **Un panneau remarque les changements externes avec un léger délai, pas instantanément.** Peach Commander vérifie le dossier courant pour des changements environ toutes les 2 secondes, de sorte qu'un fichier ajouté ou retiré par une autre application peut mettre un moment à apparaître. Si vous ne voulez pas attendre, actualisez le panneau actif manuellement avec F2 ou Ctrl+R.

## Autres limites actuelles

- **Certains chemins absolus très longs** (dossiers profondément imbriqués dont le chemin complet est inhabituellement long) peuvent ne pas être gérés de façon fiable. Travailler plus près du haut de l'arborescence évite cela.
- **Cette version préliminaire n'est pas signée.** Gatekeeper de macOS peut avertir que l'application provient d'un développeur non identifié la première fois que vous l'ouvrez. Cliquez droit sur l'application et choisissez Ouvrir, puis confirmez, pour l'exécuter. Les mises à jour automatiques ne sont pas encore disponibles dans cette version.

## Raccourcis

| Action | Raccourci |
| --- | --- |
| Actualiser le panneau actif | F2 ou Ctrl+R |
| Télécharger depuis une URL | Cmd+Maj+D |

## Remarques

Ce sont des limitations de la version actuelle et elles devraient s'améliorer dans les versions ultérieures. Si vous rencontrez un comportement non décrit ici, consultez la rubrique de dépannage.
