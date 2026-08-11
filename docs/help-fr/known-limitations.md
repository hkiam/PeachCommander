---
title: Limitations connues
slug: known-limitations
section: Aide et dépannage
order: 144
related: [troubleshooting]
---

Peach Commander fait beaucoup, mais quelques fonctionnalités ont des limites honnêtes dans la version actuelle. Les connaître à l'avance évite la confusion quand quelque chose se comporte de façon inattendue. Cette page liste les contraintes actuelles et, quand c'est possible, une solution de contournement simple.

## Archives

- **Les archives ZIP scindées (en plusieurs parties) s’ouvrent, mais toutes les parties doivent être présentes.** Le ZIP standard — y compris ZIP64, donc plus de 65 535 éléments ou plus de 4 Go — ainsi que TAR et TAR compressé en gzip s’ouvrent directement comme des dossiers. Une archive répartie sur plusieurs fichiers s’ouvre également : appuyez sur Entrée sur le `.zip` d’un jeu `.z01`, `.z02`, … ou sur le `.001` d’un jeu `name.zip.001`. Toutes les parties doivent se trouver dans le même dossier, et un jeu auquel il en manque une est refusé plutôt qu’ouvert à moitié lu. Les archives TAR scindées ne sont pas couvertes.
- **Les archives ZIP chiffrées** (l'ancien ZipCrypto comme WinZip AES) sont prises en charge pour la navigation, mais le mot de passe vous sera demandé.
- D'autres formats tels que CPIO, ISO, CAB, LZH, XAR et PAX s'ouvrent via un outil auxiliaire plutôt que par le lecteur natif.

## Réseau (SFTP / SCP)

- **En SFTP, les permissions et les dates peuvent être modifiées, le propriétaire non.** Le protocole ne transporte propriétaire et groupe que sous forme de nombres et ne permet pas de résoudre un nom d’utilisateur : un changement de propriétaire est donc refusé plutôt que deviné, comme les indicateurs de fichier macOS, qui n’existent pas en face. En FTP simple, seules les permissions peuvent être définies, via la commande optionnelle `SITE CHMOD` ; un serveur qui ne la propose pas le dit au lieu de faire semblant de réussir.
- À la première connexion à un serveur SFTP, il vous sera demandé de faire confiance à sa clé d'hôte. Peach Commander la mémorise ensuite (confiance à la première utilisation).

## Actualisation des dossiers

- **Seuls les dossiers de ce Mac sont surveillés.** Un dossier de ce Mac se met à jour de lui-même dès qu’un autre programme y ajoute, modifie ou supprime un fichier. Un emplacement distant (FTP ou SFTP) et l’intérieur d’une archive ne sont pas surveillés, car ces protocoles n’offrent aucun moyen d’être averti — appuyez sur F2 ou Ctrl+R pour les relire.

## Autres limites actuelles

- **Certains chemins absolus très longs** (dossiers profondément imbriqués dont le chemin complet est inhabituellement long) peuvent ne pas être gérés de façon fiable. Travailler plus près du haut de l'arborescence évite cela.
- **Cette version préliminaire n'est pas signée.** Gatekeeper bloque le premier lancement, et la façon de l'autoriser dépend de votre version de macOS. Sous **macOS 15 Sequoia et ultérieur** : double-cliquez une fois, fermez l'avertissement, puis allez dans **Réglages Système ▸ Confidentialité et sécurité** et cliquez sur **Ouvrir quand même** — Apple a supprimé le raccourci par clic droit pour les logiciels non signés dans macOS 15, le clic droit n'aide donc plus. Sous **macOS 13–14** : cliquez droit sur l'application, choisissez Ouvrir, puis confirmez. Les mises à jour automatiques ne sont pas encore disponibles dans cette version.

## Raccourcis

| Action | Raccourci |
| --- | --- |
| Actualiser le panneau actif | F2 ou Ctrl+R |
| Télécharger depuis une URL | Cmd+Maj+U |

## Remarques

Ce sont des limitations de la version actuelle et elles devraient s'améliorer dans les versions ultérieures. Si vous rencontrez un comportement non décrit ici, consultez la rubrique de dépannage.
