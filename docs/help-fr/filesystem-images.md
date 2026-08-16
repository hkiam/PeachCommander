---
title: Images de systèmes de fichiers
slug: filesystem-images
section: Plugins
order: 122
related: [plugins, archives, settings, viewing-files]
---

Une image de système de fichiers est un fichier contenant un système de fichiers entier — le rootfs d'une mise à jour de routeur, une carte SD copiée octet par octet, l'image d'un appareil que vous examinez. Le plugin **Linux Filesystem Images** en ouvre une comme Peach Commander ouvre une archive : placez le curseur dessus, appuyez sur Entrée, et le panneau se trouve à l'intérieur du système de fichiers. De là, la visionneuse, la recherche et la copie fonctionnent exactement comme dans un dossier.

Rien n'est jamais écrit dans une image. Le plugin ne sait que lire.

## Activez-le d'abord

Le plugin est livré désactivé. Ouvrez **Réglages ▸ Plugins**, trouvez **Linux Filesystem Images** et activez-le.

Il est désactivé par défaut à cause de sa manière de trouver les images. Un micrologiciel est rarement nommé proprement — le fichier recherché s'appelle `firmware.bin`, `rootfs.img` ou simplement `dump` au moins aussi souvent que `.squashfs` — donc lorsque l'extension ne dit rien, le plugin examine les premiers octets pour décider. C'est exactement ce qu'il faut si vous examinez des images d'appareils, et du travail inutile sinon. L'activer, c'est dire lequel des deux vous êtes.

Un fichier qui s'avère ne pas être une image est laissé tel quel après ce seul coup d'œil et s'ouvre comme il l'aurait toujours fait.

## Ce qu'il sait ouvrir

| Format | Où vous le rencontrez |
|---|---|
| SquashFS | Le rootfs de presque tous les micrologiciels de routeurs, caméras et décodeurs |
| ext2, ext3, ext4 | La partition principale de la plupart des appareils Linux embarqués |
| Btrfs | Les volumes NAS et les systèmes Linux récents, instantanés compris |
| JFFS2, UBIFS | La mémoire flash brute du matériel embarqué ancien et actuel |
| cramfs, initramfs | Les systèmes de fichiers de démarrage et les appareils anciens encore en service |
| FAT12, FAT16, FAT32 | Cartes SD, clés USB et la partition EFI de tout PC moderne |
| exFAT | Cartes SD et disques de plus de 32 Go |
| NTFS | Volumes Windows, y compris les fichiers compressés |

## Images disque comportant plusieurs partitions

Une image copiée depuis un appareil entier comporte généralement une table de partitions plutôt qu'un seul système de fichiers. Une telle image s'ouvre comme un dossier par partition — `1-rootfs`, `2-esp` — et vous entrez dans celle que vous voulez. Les tables MBR et GPT sont toutes deux lues, et lorsque la table enregistre des noms de partitions, ces noms sont utilisés.

Une partition que le plugin ne sait pas lire apparaît quand même, sous forme de dossier vide portant le nom de son type. Si un appareil a trois partitions, vous devez pouvoir voir qu'il en a trois.

## Micrologiciel sans table de partitions

Un fichier de micrologiciel extrait d’un routeur ou d’une caméra n’a généralement aucune table de partitions. C’est un en-tête du fabricant, un chargeur d’amorçage, un noyau et un rootfs écrits les uns après les autres à des décalages consignés nulle part. Un tel fichier s’ouvre avec une entrée par partie, chacune nommée d’après le décalage où elle commence : `0x00230044-squashfs` est un système de fichiers dans lequel entrer, `0x00030040-kernel.uimage` un fichier à copier.

Les parties sont trouvées en cherchant dans le fichier les systèmes de fichiers eux-mêmes, puis en ouvrant chacun d’eux pour voir s’il s’y trouve vraiment. Un motif d’octets correspondant par hasard coûte un instant et est écarté au lieu de devenir une entrée inventée ; et un fichier ne contenant aucun système de fichiers est toujours refusé et s’ouvre comme il l’aurait toujours fait.

Il en va de même pour tout ce qui se trouve en dehors des partitions d’une image partitionnée. Un Raspberry Pi garde son chargeur d’amorçage dans les mégaoctets précédant la partition 1, et U-Boot occupe sur la plupart des cartes ARM un décalage fixe dans ce même espace non attribué. Ces plages sont listées à côté des partitions afin que vous puissiez les voir et les copier.

## Consigner la structure

**Commandes ▸ Analyser la structure de l’image…** enregistre le résultat dans un fichier texte à côté de l’image et y place le curseur : chaque zone avec son décalage, sa taille et ce qu’elle s’est révélée être, ainsi que la table de partitions si l’image en possède une. C’est généralement ce tableau qu’un démontage ou un ticket réclame, et le reconstituer en parcourant un panneau et en recopiant des nombres est un travail fastidieux.

Le rapport montre aussi ce que le panneau omet — les petits espaces d’alignement entre partitions, par exemple — et nomme la carte pour laquelle un noyau U-Boot a été compilé lorsque l’image le consigne.

## Travailler dans une image

Tout ce que vous connaissez déjà s'applique. F3 affiche un fichier, F5 copie des fichiers vers un vrai dossier, et **Rechercher des fichiers** fouille le contenu de l'image. On en ressort comme d'une archive.

Les liens symboliques sont affichés avec leur nom, et en copier un vers l'extérieur donne un petit fichier texte contenant la cible du lien plutôt qu'un vrai lien — une image ne peut pas être autorisée à poser un lien pointant n'importe où sur votre propre disque.

## Quand une image ne s'ouvre pas

Le plugin vous dit pourquoi au lieu de signaler un fichier abîmé, car les deux vous mènent ailleurs :

- **Un volume Btrfs en RAID0, RAID10, RAID5 ou RAID6**, ou réparti sur plusieurs appareils. Les données sont éparpillées sur plusieurs disques, et l'essentiel n'est pas dans le fichier dont vous disposez.
- **Un vidage NAND brut contenant encore sa zone de réserve.** L'image n'a rien d'anormal ; elle a été copiée avec les octets de correction d'erreurs. Copiez-la de nouveau avec `nanddump --omitoob`.
- **Un volume ext4 ou NTFS chiffré**, illisible sans ses clés.
- **Un système de fichiers ext non démonté proprement** s'ouvre quand même, mais avec une entrée signalée en haut de sa racine avertissant que le contenu peut être périmé. Le système de fichiers a été copié pendant son utilisation, et les modifications les plus récentes sont dans un journal que ce plugin ne rejoue pas. Lancez `e2fsck` sur une copie si les détails comptent.

## Remarques

- Une image est lue une fois puis mémorisée : y revenir est immédiat.
- Les très grandes images sont lues au fur et à mesure plutôt que chargées entièrement ; une liste est plafonnée à deux millions d'entrées.
- Une image n’est fouillée à la recherche de systèmes de fichiers imbriqués que si elle n’a ni table de partitions ni système de fichiers à son début ; une image ordinaire s’ouvre donc exactement aussi vite qu’avant.
- Le plugin ajoute une commande de menu et aucun réglage propre, hormis l’interrupteur qui l’active.
