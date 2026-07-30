---
title: Confidentialité et sécurité
slug: privacy-and-security
section: macOS et confidentialité
order: 132
related: [ftp-and-sftp, troubleshooting]
---

Peach Commander est conçu pour ne pas vous gêner et garder vos données sur votre Mac. Les mots de passe sont confiés au trousseau macOS, les informations sur les plantages ne quittent jamais votre ordinateur sans votre accord, et l'application ne collecte aucune analyse d'usage. Cette rubrique explique où vivent vos informations sensibles et comment accorder l'unique autorisation système dont un gestionnaire de fichiers a besoin pour faire son travail.

## Où sont stockés les mots de passe

Tout mot de passe ou phrase secrète de clé que vous enregistrez — pour une connexion FTP ou SFTP, ou pour ouvrir une archive protégée par mot de passe — est écrit dans le **trousseau** macOS, le même stockage sécurisé que le système utilise pour vos identifiants Wi-Fi et de sites web. Les mots de passe ne sont jamais écrits en clair dans les propres réglages ou fichiers de connexion de Peach Commander.

1. Lorsque vous enregistrez un mot de passe de connexion ou d'archive, choisissez l'option de le mémoriser.
2. Le mot de passe est stocké dans votre trousseau d'ouverture de session, protégé par votre compte.
3. Pour consulter ou retirer un mot de passe enregistré plus tard, ouvrez l'app **Trousseaux d'accès** (dans Applications ▸ Utilitaires) et recherchez le nom de la connexion.

## Accorder l'accès complet au disque

macOS garde certains emplacements privés — les données de Mail, Messages et d'autres applications à l'intérieur de votre dossier Bibliothèque — jusqu'à ce que vous autorisiez explicitement l'accès. Comme un gestionnaire de fichiers est censé atteindre chaque fichier, Peach Commander demande l'**accès complet au disque**. L'application continue de fonctionner avec un accès réduit tant que vous ne l'accordez pas ; vous ne verrez simplement pas ces dossiers protégés.

1. Choisissez **Commandes ▸ Accès complet au disque…**, ou cliquez sur **Ouvrir les Réglages Système** lorsque l'application propose de vous guider au lancement.
2. Dans **Réglages Système ▸ Confidentialité et sécurité ▸ Accès complet au disque**, activez l'interrupteur à côté de Peach Commander.
3. Relancez l'application si on vous y invite.

## Les rapports de plantage restent locaux

Si l'application quitte de façon inattendue, macOS écrit un rapport de plantage dans votre propre dossier de diagnostics. Au lancement suivant, Peach Commander le remarque et propose de vous aider à déposer un rapport de bogue — mais seulement avec votre consentement.

- Vous pouvez **Afficher dans le Finder** pour voir le rapport, ou **Copier le rapport dans le presse-papiers** pour le coller vous-même dans un rapport de bogue.
- Rien n'est jamais transmis automatiquement, et aucun service tiers de rapport de plantage n'est impliqué.

## Remarques

- **Aucune télémétrie.** Peach Commander ne suit pas votre activité et n'envoie d'analyse d'usage nulle part.
- **L'accès réduit est sûr.** Si vous ignorez l'accès complet au disque, l'application parcourt et gère quand même les fichiers que vous voyez normalement ; seuls les emplacements protégés par le système sont masqués.
- **Vous contrôlez les mots de passe enregistrés.** Comme les identifiants vivent dans le trousseau, vous les gérez et les révoquez avec les outils standard de macOS plutôt que dans l'application.
