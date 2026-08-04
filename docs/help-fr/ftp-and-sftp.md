---
title: Se connecter en FTP et SFTP
slug: ftp-and-sftp
section: Réseau et accès distant
order: 100
related: [downloading-from-url, network-shares]
---

Peach Commander peut parcourir des serveurs distants comme s'ils étaient des dossiers ordinaires. Une fois connecté, un panneau affiche les fichiers distants et vous les copiez, déplacez, renommez et supprimez avec les mêmes touches qu'en local. Il parle le FTP simple, le FTPS sécurisé et le SFTP/SCP via SSH, de sorte que vous pouvez atteindre aussi bien un hébergeur web classique qu'un serveur SSH renforcé. Les connexions enregistrées vivent dans le gestionnaire de connexions, et les mots de passe sont conservés en sécurité dans votre trousseau macOS plutôt que dans la connexion elle-même.

## Se connecter à un serveur

1. Ouvrez le menu **Réseau** et choisissez **Connexion FTP…** (Ctrl+F) pour ouvrir le gestionnaire de connexions.
2. Choisissez une connexion enregistrée dans la liste et cliquez sur **Se connecter**, ou cliquez sur **Nouveau** pour en créer une. Utilisez les dossiers de la liste pour regrouper les connexions.
3. Pour une connexion ponctuelle rapide, choisissez **Réseau > Nouvelle connexion FTP…** (Ctrl+N) et saisissez l'adresse directement.
4. Saisissez votre mot de passe lorsqu'il est demandé ; cochez l'option pour l'enregistrer et il va dans votre trousseau pour la prochaine fois.
5. Quand vous avez terminé, choisissez **Réseau > Déconnexion FTP** (Ctrl+Maj+F).

![Le gestionnaire de connexions FTP montrant la liste des sessions enregistrées avec les boutons Nouveau, Modifier et Supprimer](screenshots/ftp-connection-manager.png)
*(Figure : le gestionnaire de connexions contient vos serveurs enregistrés ; utilisez Nouveau, Modifier et Supprimer pour les gérer.)*

Lorsque vous configurez une connexion, vous pouvez choisir le protocole (FTP, FTPS avec AUTH TLS explicite, FTPS implicite sur le port 990, ou SFTP/SCP), le mode passif ou actif, les dossiers de départ distant et local, l'encodage de texte et un intervalle keep-alive facultatif pour empêcher les serveurs inactifs de vous déconnecter. Pour SFTP, vous pouvez vous authentifier avec votre agent SSH, un mot de passe ou un fichier de clé privée, et vous pouvez choisir SCP pour les transferts. Les clés d'hôte SSH inconnues sont approuvées à la première utilisation ; si la clé d'un serveur connu change un jour, la connexion est refusée pour vous protéger d'une altération.

## La console FTP

Pour voir exactement ce que dit le serveur, ouvrez la console FTP depuis le menu **Réseau**. Elle affiche un journal en direct du canal de contrôle (votre mot de passe est masqué) et vous permet de saisir des commandes FTP brutes au serveur.

![La console FTP montrant le journal du canal de contrôle et un champ pour les commandes brutes](screenshots/ftp-console.png)
*(Figure : la console FTP journalise chaque échange et accepte des commandes brutes, ce qui est pratique pour le dépannage.)*

## Raccourcis

| Action | Raccourci |
| --- | --- |
| Ouvrir le gestionnaire de connexions | Ctrl+F |
| Nouvelle connexion | Ctrl+N |
| Se déconnecter | Ctrl+Maj+F |
| Changer le mode de transfert | Ctrl+Maj+M |

## Remarques

- Un téléchargement interrompu reprend là où il s’est arrêté : si le fichier est déjà partiellement présent et que le serveur accepte une reprise, seule la fin manquante circule. Un serveur qui refuse reprend simplement le fichier au début. Les envois ne reprennent pas encore.
- Pour les serveurs FTPS avec un certificat auto-signé, activez l'option pour accepter un certificat non fiable dans les réglages de cette connexion.
- Un proxy SOCKS5 peut être défini par connexion pour le FTP simple. Acheminer une connexion FTPS chiffrée par un proxy n'est pas pris en charge.
- Les connexions FTP existantes de Total Commander peuvent être importées.
- SCP n'est utilisé que pour transférer des fichiers ; le listage, le renommage et la suppression passent toujours par SFTP.
