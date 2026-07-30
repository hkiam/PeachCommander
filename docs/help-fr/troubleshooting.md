---
title: Dépannage
slug: troubleshooting
section: Aide et dépannage
order: 140
related: [privacy-and-security, known-limitations]
---

Cette rubrique couvre les problèmes les plus fréquents : macOS bloquant l'accès à certains dossiers, un dossier qui semble figé sur un ancien contenu, un serveur FTP sécurisé qui refuse de se connecter, et la compression en RAR. Chaque section vous indique ce qui se passe et comment le corriger.

## macOS demande une autorisation, ou les dossiers semblent vides

Certains emplacements — comme votre dossier `~/Library`, les dossiers d'autres utilisateurs et les zones système — sont protégés par macOS et restent masqués jusqu'à ce que vous accordiez l'accès. Peach Commander détecte quand cela se produit et propose de vous guider vers le bon réglage.

1. Lorsqu'on vous y invite, choisissez d'ouvrir les Réglages Système, ou ouvrez-les vous-même.
2. Allez dans Confidentialité et sécurité, puis Accès complet au disque.
3. Activez l'interrupteur à côté de Peach Commander. S'il n'est pas listé, utilisez le bouton Ajouter pour l'ajouter.
4. Quittez et rouvrez Peach Commander pour que la nouvelle autorisation prenne effet.

Peach Commander ne s'exécute pas dans un bac à sable restreint, donc une fois l'accès complet au disque accordé, il peut parcourir et gérer les fichiers exactement comme le Finder.

## Un dossier n'affiche pas les changements récents

Les panneaux se mettent normalement à jour tout seuls quand les fichiers changent sur le disque. Si un dossier a été modifié par un autre programme, se trouve sur un volume réseau, ou semble simplement obsolète, actualisez-le manuellement.

1. Cliquez sur le panneau à mettre à jour.
2. Appuyez sur F2 (ou Ctrl+R) pour relire ce dossier.

Les volumes réseau et montés ne signalent pas toujours les changements à macOS, une actualisation manuelle est donc la solution fiable là-bas.

## Un serveur FTPS ne se connecte pas

Si une connexion FTP sécurisée échoue, vérifiez ces réglages dans les détails de la connexion :

- Accordez le mode de sécurité du serveur : FTPS explicite (AUTH TLS) et FTPS implicite (port 990) ne sont pas interchangeables.
- Si la connexion se bloque après l'authentification, basculez entre le mode de transfert passif et actif — la plupart des serveurs derrière un pare-feu ont besoin du mode passif.
- Si le serveur utilise un certificat auto-signé, vous devez explicitement l'autoriser ; sinon la connexion est refusée.
- Confirmez l'hôte, le port, le nom d'utilisateur et le mot de passe, et si un proxy SOCKS5 est requis sur votre réseau.

## La compression en RAR ne fait rien

Peach Commander peut créer des archives ZIP, 7z, TAR, TAR.GZ, BZ2 et XZ tout seul. RAR est différent : parce que RAR est un format propriétaire, la création d'archives RAR nécessite un outil en ligne de commande RAR séparé installé sur votre Mac. Sans lui, RAR est indisponible quand vous compressez des fichiers (Option+F5). Pour lire les archives RAR existantes, vous pouvez toujours les ouvrir comme un dossier. Si vous n'avez pas spécifiquement besoin de RAR, choisissez plutôt ZIP ou 7z — les deux prennent en charge un chiffrement AES-256 robuste et les volumes fractionnés.

## Raccourcis

| Action | Raccourci |
| --- | --- |
| Actualiser le dossier actif | F2 ou Ctrl+R |
| Se connecter à un serveur FTP/FTPS | Ctrl+F |
| Monter un partage réseau | Cmd+K |
| Compresser les fichiers sélectionnés | Option+F5 |

## Remarques

- Les mots de passe et autres identifiants sont stockés uniquement dans le trousseau macOS, jamais dans des fichiers de configuration en clair.
- Monter un partage réseau (Cmd+K, ou menu Réseau ▸ Monter un partage réseau…) utilise la même connexion que macOS lui-même, de sorte qu'il apparaîtra aussi dans le Finder.
- Si un problème persiste après une actualisation et un redémarrage, il peut s'agir d'une limitation connue plutôt que d'une défaillance — voir Limitations connues.
