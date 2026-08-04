---
title: Limitations connues
slug: known-limitations
section: Aide et dépannage
order: 144
related: [troubleshooting]
---

Peach Commander fait beaucoup, mais quelques fonctionnalités ont des limites honnêtes dans la version actuelle. Les connaître à l'avance évite la confusion quand quelque chose se comporte de façon inattendue. Cette page liste les contraintes actuelles et, quand c'est possible, une solution de contournement simple.

## Archives

- **Les archives scindées (en plusieurs parties) ne peuvent pas être ouvertes.** Le ZIP standard — y compris ZIP64, donc plus de 65 535 éléments ou plus de 4 Go — ainsi que TAR et TAR compressé en gzip s’ouvrent directement comme des dossiers. Une archive répartie sur plusieurs fichiers (`.z01`, `.zip.001`) n’est pas prise en charge : réunissez d’abord les parties, ou décompressez-la avec l’outil qui l’a créée.
- **Les archives ZIP chiffrées** (l'ancien ZipCrypto comme WinZip AES) sont prises en charge pour la navigation, mais le mot de passe vous sera demandé.
- D'autres formats tels que CPIO, ISO, CAB, LZH, XAR et PAX s'ouvrent via un outil auxiliaire plutôt que par le lecteur natif.

## Réseau (SFTP / SCP)

- **Changer les attributs de fichier via SFTP n'a aucun effet dans cette version.** Vous pouvez parcourir, télécharger et envoyer via SFTP/SCP, mais les demandes de changement de permissions, de propriété ou d'horodatages sur un serveur distant sont ignorées en silence. Effectuez ces changements sur le serveur lui-même, ou via un autre protocole.
- À la première connexion à un serveur SFTP, il vous sera demandé de faire confiance à sa clé d'hôte. Peach Commander la mémorise ensuite (confiance à la première utilisation).

## Télécharger depuis une URL

- La commande **Télécharger depuis une URL** (menu Réseau) utilise actuellement le raccourci Cmd+Maj+D, qui est le même que Aller > Bureau. Quand les deux sont disponibles, les menus peuvent entrer en conflit — lancez le téléchargement directement depuis le menu Réseau pour être sûr.

## Actualisation des dossiers

- **Seuls les dossiers de ce Mac sont surveillés.** Un dossier de ce Mac se met à jour de lui-même dès qu’un autre programme y ajoute, modifie ou supprime un fichier. Un emplacement distant (FTP ou SFTP) et l’intérieur d’une archive ne sont pas surveillés, car ces protocoles n’offrent aucun moyen d’être averti — appuyez sur F2 ou Ctrl+R pour les relire.

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
