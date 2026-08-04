---
title: Télécharger depuis une URL
slug: downloading-from-url
section: Réseau et accès distant
order: 102
related: [ftp-and-sftp]
---

Peach Commander peut récupérer un fichier directement depuis une adresse web HTTP ou HTTPS vers le panneau actif, sans ouvrir de navigateur. Collez un lien, confirmez le nom sous lequel il sera enregistré, et le téléchargement se déroule tout seul — avec reprise si la connexion tombe, téléchargements par lots pour plusieurs liens à la fois, et vérification facultative de la somme de contrôle pour que vous sachiez que le fichier est arrivé intact.

## Télécharger un fichier

1. Ouvrez le dossier du panneau où vous voulez que le fichier arrive.
2. Choisissez **Réseau > Télécharger depuis une URL**, ou appuyez sur Cmd+Maj+U.
3. Collez l'adresse web dans le champ **URL(s)**. Si vous avez copié un lien au préalable, il est renseigné pour vous.
4. Vérifiez le nom **Enregistrer sous** — il est suggéré à partir du lien et vous pouvez le modifier librement.
5. Cliquez sur **Télécharger**.

![Le dialogue Télécharger depuis une URL avec un lien, un nom de fichier modifiable et des options](screenshots/download-url.png)
*(Figure : le dialogue de téléchargement — collez un lien, modifiez le nom et réglez la vérification, les identifiants, les en-têtes ou un proxy facultatifs.)*

Par défaut, le téléchargement s'exécute **en arrière-plan**, vous pouvez donc continuer à travailler dans les panneaux pendant le transfert. Désactivez **Télécharger en arrière-plan** pour l'attendre, ou activez **Mettre en file pour plus tard** pour le configurer sans le démarrer encore.

## Télécharger plusieurs fichiers à la fois

Collez une adresse web par ligne dans le champ **URL(s)**. Lorsque plusieurs liens sont présents, le nom de chaque fichier est dérivé automatiquement de son lien, et les champs **Enregistrer sous** et **Vérifier** par fichier sont désactivés.

## Reprendre un téléchargement interrompu

Si un transfert est coupé, Peach Commander conserve ce qu'il a déjà reçu dans un fichier temporaire `.part`. Relancer le même téléchargement reprend là où il s'est arrêté chaque fois que le serveur le prend en charge, plutôt que de recommencer. Le fichier `.part` est renommé au nom final seulement une fois le téléchargement terminé avec succès.

## Raccourcis

| Action | Raccourci |
| --- | --- |
| Télécharger depuis une URL | Cmd+Maj+U |

## Astuces

- **Vérifiez le fichier.** Pour un téléchargement unique, collez une somme de contrôle **SHA-256** attendue dans le champ **Vérifier**. Après le transfert, la somme de contrôle du fichier est comparée à celle-ci pour que vous puissiez avoir confiance que le fichier correspond à ce que l'éditeur a indiqué.
- **Connexion requise ?** Saisissez un nom d'utilisateur et un mot de passe dans les champs **Auth** pour les sites utilisant l'authentification basique. Pour un accès par jeton, ajoutez une ligne `Authorization: Bearer …` dans le champ **En-têtes**.
- **En-têtes personnalisés.** Ajoutez un en-tête par ligne dans le champ **En-têtes**, par exemple `Referer: …` ou `Cookie: …`, pour les liens qui ne fonctionnent qu'avec des en-têtes de requête spécifiques.
- **Proxy.** Acheminez le téléchargement par un proxy HTTP ou SOCKS5 en renseignant l'hôte, le port et le type du **Proxy**.
- **Certificats non fiables.** N'activez **Autoriser un certificat non fiable** que pour un site de confiance utilisant un certificat auto-signé ; cela désactive le contrôle de sécurité HTTPS normal pour ce téléchargement.
- **Remarque :** le raccourci était Cmd+Maj+D, que Aller ▸ Bureau utilise aussi — l’un des deux ne se déclenchait donc jamais. Le téléchargement est passé à Cmd+Maj+U (U pour URL) et Bureau garde Cmd+Maj+D, comme dans le Finder.
