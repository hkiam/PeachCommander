---
title: Serveurs WebDAV
slug: webdav
section: Extensions
order: 130
related: [plugins, ftp-and-sftp, network-shares]
---

Un serveur WebDAV — Nextcloud, ownCloud, un Synology, un espace de stockage universitaire — se parcourt dans un panneau comme n’importe quel dossier. Choisissez **Connexion WebDAV…** dans le menu Réseau, indiquez une URL, et le serveur apparaît dans le panneau actif.

C’est une extension : vous pouvez la désactiver ou la supprimer dans **Configuration ▸ Extensions…**.

## Se connecter

L’URL est la collection dans laquelle vous voulez arriver, avec votre nom d’utilisateur devant l’hôte :

```
https://anna@files.example.com/remote.php/dav/files/anna/
```

Le mot de passe est demandé séparément et va dans le **trousseau** via l’hôte, jamais dans un fichier de configuration. Laissez-le vide lors d’une connexion ultérieure et celui qui est enregistré sera utilisé.

Chaque URL à laquelle vous vous connectez est retenue — les trente dernières, la plus récente en premier — et proposée la fois suivante dans le menu déroulant. Cette liste se trouve dans `~/Library/Application Support/PeachCommander/webdav/sites.json` et ne contient **que des URL** ; aucun mot de passe n’y est jamais écrit.

## Utilisez https

L’authentification est HTTP Basic, ce qui veut dire que votre nom d’utilisateur et votre mot de passe voyagent encodés en base64 — encodés, pas chiffrés. En `https://`, la connexion les protège. En `http://`, ils sont pratiquement en clair, et tout ce qui se trouve entre vous et le serveur peut les lire. Le simple `http://` est accepté, car un serveur sur votre propre machine ou sur un réseau de laboratoire fermé est un cas légitime — ce n’est pas pour autant un bon réglage par défaut.

## Ce que vous pouvez faire

Lister, lire, écrire, créer des dossiers, supprimer, renommer et déplacer fonctionnent tous — ils correspondent aux verbes WebDAV `PROPFIND`, `GET`, `PUT`, `MKCOL`, `DELETE` et `MOVE`. Un panneau sur un serveur WebDAV se comporte donc comme un panneau sur un disque pour le travail quotidien.

## À quoi s’attendre

**Les transferts portent sur le fichier entier.** Un fichier est récupéré ou envoyé d’un seul tenant ; il n’y a pas de transfert par plages, donc un transfert interrompu d’un gros fichier recommence au lieu de reprendre.

**Copier à l’intérieur du serveur passe par votre Mac.** L’extension n’utilise pas le verbe `COPY` : dupliquer un fichier sur le serveur le télécharge puis le renvoie. Sur une ligne lente, déplacer — ce que le serveur fait lui-même — est bien plus rapide que copier.

**Rien n’est verrouillé.** Le `LOCK` de WebDAV n’est pas utilisé : si deux personnes écrivent le même fichier en même temps, c’est le dernier enregistrement qui tranche, exactement comme sur un partage réseau sans verrouillage.

**Authentification Basic uniquement.** Les serveurs qui exigent Digest, un jeton bearer ou un parcours d’authentification unique refuseront la connexion. Beaucoup d’entre eux proposent à la place un mot de passe spécifique à l’application, qui fonctionne ici.
