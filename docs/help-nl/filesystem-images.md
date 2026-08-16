---
title: Bestandssysteemimages
slug: filesystem-images
section: Plugins
order: 122
related: [plugins, archives, settings, viewing-files]
---

Een bestandssysteemimage is een bestand met een compleet bestandssysteem erin — de rootfs uit een routerupdate, een byte voor byte gekopieerde SD-kaart, het image van een apparaat dat u onderzoekt. De plug-in **Linux Filesystem Images** opent zo'n bestand zoals Peach Commander een archief opent: zet de cursor erop, druk op Enter, en het paneel staat in het bestandssysteem. Vanaf daar werken de viewer, het zoeken en het kopiëren precies als in een map.

Er wordt nooit naar een image geschreven. De plug-in kan alleen lezen.

## Zet hem eerst aan

De plug-in wordt uitgeschakeld geleverd. Open **Instellingen ▸ Plug-ins**, zoek **Linux Filesystem Images** en schakel hem in.

Hij staat standaard uit vanwege de manier waarop hij images vindt. Firmware heeft zelden een nette naam — het bestand dat u zoekt heet minstens zo vaak `firmware.bin`, `rootfs.img` of gewoon `dump` als `.squashfs` — dus als de extensie niets zegt, kijkt de plug-in naar de eerste bytes om het te bepalen. Dat is precies goed als u apparaatimages onderzoekt, en nutteloos werk als u dat nooit doet. Inschakelen is hoe u zegt welke van de twee u bent.

Een bestand dat geen image blijkt te zijn, blijft na die ene blik ongemoeid en opent zoals het altijd al zou doen.

## Wat het kan openen

| Formaat | Waar u het tegenkomt |
|---|---|
| SquashFS | De rootfs in vrijwel elke router-, camera- en settopboxfirmware |
| ext2, ext3, ext4 | De hoofdpartitie van de meeste embedded Linux-apparaten |
| Btrfs | NAS-volumes en nieuwere Linux-systemen, inclusief snapshots |
| JFFS2, UBIFS | Ruw flashgeheugen in oudere en huidige embedded hardware |
| cramfs, initramfs | Opstartbestandssystemen en langlevende oudere apparaten |
| FAT12, FAT16, FAT32 | SD-kaarten, USB-sticks en de EFI-partitie van elke moderne pc |
| exFAT | SD-kaarten en schijven boven de 32 GB |
| NTFS | Windows-volumes, inclusief gecomprimeerde bestanden |

## Schijfimages met meerdere partities

Een image dat van een heel apparaat is gekopieerd heeft meestal een partitietabel in plaats van één bestandssysteem. Zo'n image opent als één map per partitie — `1-rootfs`, `2-esp` — en u stapt in welke u maar wilt. Zowel MBR- als GPT-partitietabellen worden gelezen, en waar de tabel partitienamen vastlegt, worden die namen gebruikt.

Een partitie die de plug-in niet kan lezen verschijnt toch, als lege map met de naam van het type. Heeft een apparaat drie partities, dan moet u kunnen zien dat het er drie heeft.

## Werken in een image

Alles wat u al kent blijft gelden. F3 toont een bestand, F5 kopieert bestanden naar een echte map, en **Bestanden zoeken** doorzoekt de inhoud van het image. U verlaat het zoals u een archief verlaat.

Symbolische koppelingen worden met hun naam getoond, en er een naar buiten kopiëren geeft een klein tekstbestand met het doel van de koppeling in plaats van een echte koppeling — een image mag geen koppeling plaatsen die ergens op uw eigen schijf wijst.

## Wanneer een image niet opent

De plug-in zegt waarom in plaats van een kapot bestand te melden, want die twee brengen u elders:

- **Een Btrfs-volume met RAID0, RAID10, RAID5 of RAID6**, of verdeeld over meerdere apparaten. De gegevens staan verspreid over schijven en het meeste staat niet in het bestand dat u heeft.
- **Een ruwe NAND-dump die zijn reservegebied nog bevat.** Met het image is niets mis; het is gekopieerd inclusief de foutcorrectiebytes. Kopieer het opnieuw met `nanddump --omitoob`.
- **Een versleuteld ext4- of NTFS-volume**, dat zonder de sleutels niet te lezen is.
- **Een niet netjes afgesloten ext-bestandssysteem** opent nog steeds, maar met een gemarkeerde regel bovenaan de hoofdmap die waarschuwt dat de inhoud verouderd kan zijn. Het bestandssysteem is tijdens gebruik gekopieerd en de nieuwste wijzigingen staan in een journaal dat deze plug-in niet afspeelt. Draai `e2fsck` op een kopie als de details ertoe doen.

## Opmerkingen

- Een image wordt één keer gelezen en onthouden, dus er weer instappen gaat direct.
- Zeer grote images worden gelezen wanneer nodig in plaats van in hun geheel geladen; een lijst is begrensd op twee miljoen items.
- De plug-in voegt geen menuopdrachten en geen eigen instellingen toe, afgezien van de schakelaar die hem aanzet.
