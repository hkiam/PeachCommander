---
title: Partages réseau
slug: network-shares
section: Réseau et accès distant
order: 104
related: [ftp-and-sftp]
---

Peach Commander peut se connecter à des serveurs de fichiers de votre réseau local ou d'entreprise — partages SMB (Windows/Samba) et AFP — et afficher leur contenu dans un panneau tout comme un dossier de votre propre Mac. Une fois un partage connecté, vous pouvez parcourir, copier, déplacer, renommer et ouvrir des fichiers dedans exactement comme en local, y compris copier entre le partage et votre autre panneau.

## Se connecter à un serveur

1. Cliquez sur le panneau auquel vous voulez vous connecter (le partage connecté s'ouvre dans le panneau actif).
2. Appuyez sur Cmd+K, ou choisissez **Réseau > Voisinage réseau > Connecter un partage réseau…**.
3. Dans le dialogue **Se connecter au serveur**, saisissez l'adresse du serveur. Vous pouvez indiquer :
   - une adresse SMB, par exemple `smb://fileserver/projects`
   - une adresse AFP, par exemple `afp://fileserver/projects`
   - un chemin de style Windows, par exemple `\\fileserver\projects`
   - un simple nom `serveur/partage`
4. Cliquez sur Se connecter (ou appuyez sur Retour). Si le serveur a besoin d'un nom et d'un mot de passe, macOS affiche sa fenêtre de connexion habituelle — saisissez-y vos informations.
5. Une fois le partage prêt, le panneau actif l'ouvre automatiquement. Parcourez-le et travaillez avec comme avec n'importe quel autre dossier.

## Se déconnecter

Un partage connecté apparaît comme un volume monté sur votre Mac. Pour le déconnecter, éjectez-le de la façon habituelle de macOS — par exemple depuis la barre latérale du Finder ou depuis la liste des appareils de Peach Commander.

## Raccourcis

| Action | Raccourci |
| --- | --- |
| Connecter un partage réseau… | Cmd+K |

## Remarques

- L'authentification (nom d'utilisateur, mot de passe et une option facultative « mémoriser dans mon trousseau ») est gérée par la fenêtre de connexion habituelle de macOS, de sorte que les mots de passe de serveur enregistrés fonctionnent comme dans le Finder.
- Si vous saisissez une adresse impossible à interpréter, Peach Commander vous demande une adresse SMB/AFP, un chemin de style Windows ou un nom `serveur/partage`, et rien n'est monté.
- Après confirmation, la connexion peut prendre un moment pendant que macOS monte le partage ; le panneau bascule dessus dès qu'il devient disponible.
- Cela connecte à des appareils partagés sur un réseau. Pour atteindre plutôt un serveur FTP, FTPS ou SFTP, consultez la rubrique liée ci-dessous.
