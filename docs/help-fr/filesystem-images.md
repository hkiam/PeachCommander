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
- Le plugin n'ajoute aucune commande de menu ni réglage propre, hormis l'interrupteur qui l'active.
