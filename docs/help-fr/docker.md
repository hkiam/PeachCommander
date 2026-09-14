---
title: Conteneurs et volumes Docker
slug: docker
section: Extensions
order: 137
related: [plugins, amazon-s3, webdav, copying-files, privacy-and-security]
---

Le système de fichiers d’un conteneur Docker se parcourt dans un panneau comme n’importe quel dossier, et un volume Docker également. Choisissez **Se connecter à Docker…** dans le menu Réseau, ou cliquez sur la pastille **Docker** dans la barre de volumes, et le moteur apparaît dans le panneau actif.

C’est une extension, et elle est **livrée désactivée**. Activez-la dans **Configuration ▸ Extensions…**. Elle démarre désactivée parce qu’une connexion au démon Docker dispose sur votre Mac des mêmes droits que vous — voir *Ce à quoi elle accède* plus bas.

## Ce que vous voyez

Le niveau supérieur comporte trois dossiers :

- **Compose Projects** — tous les conteneurs lancés par Docker Compose, groupés par projet puis par service. Un service à un seul conteneur *est* ce conteneur : `my-stack/backend/etc` est le `/etc` du backend. Un service qui en compte plusieurs conserve un niveau pour eux, un dossier par conteneur.
- **Standalone Containers** — tout le reste, en fonctionnement ou non.
- **Volumes** — chaque volume Docker, comme un disque à part entière.

En dessous, vous êtes dans un vrai système de fichiers : F3 affiche un fichier, F4 le modifie, F5 le copie vers l’autre panneau, F7 crée un dossier. L’autre panneau peut être n’importe quoi — un dossier local, une archive, un compartiment S3.

Le regroupement est lu dans les étiquettes que Compose appose sur ses propres conteneurs et volumes ; il reste donc exact même pour une pile dont le `docker-compose.yml` n’est plus sur cette machine.

**Les volumes sont listés à part volontairement.** Un volume survit au conteneur qui l’a créé, peut être partagé par plusieurs conteneurs, et contient généralement les données qui vous intéressent. Un volume qu’aucun conteneur ne monte actuellement reste consultable.

## Colonnes

Un clic droit sur l’en-tête de colonne d’un panneau ajoute les colonnes propres au fournisseur :

- **État** — `● running`, `○ stopped`, `◌ paused`, `! restarting`.
- **Accès** — `RW`, `RO` pour un rootfs ou un montage en lecture seule, `VOL` pour un volume Docker, `BIND` pour un de vos dossiers monté dans le conteneur, `TMP` pour un tmpfs.
- **Image**, **ID**.
- **Montage** — sur un dossier qui est en réalité un montage, ce qu’il est : `Volume: my-stack_db-data`, ou le chemin hôte derrière un bind. C’est ainsi que vous trouvez quel volume sous **Volumes** contient les données d’un conteneur.

## Conteneurs arrêtés

Les conteneurs arrêtés sont listés et leurs systèmes de fichiers peuvent être lus et écrits. L’API fichier de Docker répond pour un conteneur qui n’a pas tourné depuis un mois, et c’est ce qui donne l’impression d’un disque plutôt que d’une liste de processus.

Deux opérations exigent un conteneur réellement en fonctionnement : **supprimer** et **renommer**. L’API du moteur Docker n’offre ni l’une ni l’autre — la seule façon de retirer ou de déplacer un fichier dans un conteneur est d’y exécuter quelque chose — aussi sont-elles refusées plutôt que simulées sur un conteneur arrêté.

## Ce qu’il faut en attendre

**Les écritures entrent en tant que `root`, les suppressions passent par l’utilisateur du conteneur.** C’est l’organisation de Docker, pas un choix fait ici : copier un fichier vers l’intérieur utilise l’API d’archive du moteur, qui écrit en root ; supprimer ou renommer exécute une commande dans le conteneur, sous l’utilisateur configuré par l’image. Une suppression peut donc être refusée pour *permission refusée* sur un fichier que vous veniez de copier. Peach Commander ne contourne pas cela en agissant en root — il vous rapporte ce que le conteneur a dit.

**Un conteneur ou un montage en lecture seule refuse l’écriture**, et le signale comme une erreur de droits et non comme un échec.

**Lire un lien symbolique lit sa cible.** Le panneau continue de l’afficher comme un lien dans la colonne Attr ; F3 montre le contenu de la cible plutôt qu’un fichier vide.

**La racine d’un gros conteneur arrêté peut ne pas être listable.** Docker n’a aucun appel qui liste un dossier. Lire un dossier revient à le demander sous forme d’archive, laquelle contient tout ce qui se trouve dessous — pour un conteneur arrêté bâti sur une image complète, cela peut représenter des dizaines de gigaoctets, et le listage est alors refusé plutôt que tout lire. Les dossiers plus profonds ne sont pas concernés, et un conteneur *en fonctionnement* non plus : un dossier trop volumineux pour l’archive est listé par le conteneur lui-même. Si vous ne voulez que la voie de l’archive, voyez le réglage ci-dessous.

**Copier un conteneur entier copie tout son système de fichiers** — y compris `/proc` et `/dev`. Copiez le dossier voulu, pas `/`.

## Ce à quoi elle accède

L’extension dialogue avec le moteur que vous atteindriez depuis un terminal : `DOCKER_HOST` si vous l’avez défini, sinon votre `docker context` courant, sinon les sockets habituels de Docker Desktop, Colima, Rancher Desktop, Lima et Podman. Podman fonctionne parce qu’il expose la même API.

L’accès à un démon Docker signifie généralement un accès très étendu à la machine qui l’héberge. L’extension possède exactement vos droits et n’en demande pas davantage : elle ne conserve aucun identifiant, ne touche jamais aux répertoires propres à Docker sur votre disque et n’effectue aucune action privilégiée en votre nom.

La seule chose qu’elle crée est un **conteneur jetable** — uniquement pour atteindre un volume qu’aucun conteneur existant ne monte, puisqu’un volume n’est visible que depuis l’intérieur de quelque chose qui le monte. Il n’est jamais démarré, il porte une étiquette de Peach Commander, et il est supprimé dès que vous quittez le disque.

## Actions sur un conteneur ou un volume

Un clic droit sur un conteneur ou un volume propose, dans le sous-menu **Docker**, ce qu’un disque seul ne peut pas dire :

- **Inspect** — tout ce que le moteur sait à son sujet, en JSON formaté, dans une fenêtre où l’on peut
  faire défiler et sélectionner.
- **Show Logs** — les 500 dernières lignes écrites par le conteneur.
- **Show Mounts** — chaque montage qu’il porte, ce qu’il est, et s’il est accessible en écriture.
- **Copy ID** — l’identifiant complet du conteneur, ou le nom du volume, dans le presse-papiers.
  L’identifiant *complet*, pas les douze caractères de la colonne ID : c’est fait pour être collé dans
  une commande `docker`, et un identifiant court est un préfixe qui peut cesser d’être unique.
- **Jump to Volume** — sur un dossier qui est en réalité un volume, aller à ce volume sous
  **Volumes**. C’est l’autre moitié de la colonne Montage : la colonne nomme le volume, ceci vous y emmène.
- **Open Compose Project** — aller au projet auquel appartient le conteneur.
- **Start**, **Stop**, **Restart**, **Pause**, **Unpause** — celles-ci modifient le conteneur au
  lieu de le lire, elles demandent donc d’abord. Start est aussi la sortie des deux refus ci-dessus :
  supprimer et renommer exigent un conteneur en fonctionnement.

Ces entrées n’apparaissent qu’à l’intérieur d’un disque Docker ; sur un de vos dossiers, elles ne sont pas là du tout.

**Le journal est aussi un fichier.** La racine de chaque conteneur contient `docker-logs.txt` — qui n’est pas un fichier du conteneur : le lire demande le journal au moteur. F3 dessus l’ouvre dans la visionneuse, si bien que sa recherche, son saut à une ligne et son choix d’encodage s’appliquent, ce qu’une fenêtre à part ne peut pas offrir. Un conteneur qui embarque réellement un fichier de ce nom montre le sien, et rien ne peut être écrit dans le fichier virtuel.

## Réglages

**Configuration ▸ Réglages ▸ Docker** contient tout cela. Les mêmes valeurs vivent dans un petit fichier dans `~/Library/Application Support/PeachCommander/Docker/docker.ini`, à modifier si vous préparez une machine par script :

- `Endpoint` — une adresse à utiliser à la place de celle qui a été trouvée.
- `ExecFallback` — `0` limite l’extension à l’API d’archive de Docker : elle n’exécutera alors jamais rien dans un conteneur, au prix de ne pas pouvoir lister un très gros dossier, ni supprimer, ni renommer.
- `ProbeBudgetMB`, `MaxBudgetMB`, `MaxBudgetSeconds` — quelle part de l’archive d’un dossier vaut la peine d’être lue avant de se rabattre ou d’abandonner.
- `HelperImage` — l’image dont est fait le conteneur jetable ci-dessus (par défaut, n’importe quelle image déjà présente).
- `ShowAnonymousVolumes` — `0` masque les volumes auxquels Docker a donné une longue empreinte pour nom, faute de nom donné par quelqu’un d’autre.

## Absent de cette version

Les moteurs distants via SSH ou TLS, un shell interactif, et les images comme systèmes de fichiers en lecture seule.
