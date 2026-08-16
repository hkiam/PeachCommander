---
title: Filsystemsbilleder
slug: filesystem-images
section: Plugins
order: 122
related: [plugins, archives, settings, viewing-files]
---

Et filsystemsbillede er en fil, der indeholder et helt filsystem — rootfs fra en routeropdatering, et SD-kort kopieret byte for byte, aftrykket af en enhed, du undersøger. Pluginet **Linux Filesystem Images** åbner et sådant, som Peach Commander åbner et arkiv: sæt markøren på det, tryk på Enter, og panelet står inde i filsystemet. Derfra virker fremviseren, søgningen og kopieringen præcis som i en mappe.

Der skrives aldrig til et billede. Pluginet kan udelukkende læse.

## Slå det til først

Pluginet leveres slået fra. Åbn **Indstillinger ▸ Plugins**, find **Linux Filesystem Images**, og slå det til.

Det er slået fra som standard på grund af den måde, det finder billeder på. Firmware har sjældent et pænt navn — filen, du leder efter, hedder mindst lige så ofte `firmware.bin`, `rootfs.img` eller bare `dump` som `.squashfs` — så når endelsen intet siger, kigger pluginet på de første byte for at afgøre det. Det er lige det rigtige, hvis du undersøger enhedsbilleder, og spildt arbejde, hvis du aldrig gør. At slå det til er din måde at sige, hvilken af de to du er.

En fil, der viser sig ikke at være et billede, bliver urørt efter det ene kig og åbner, som den altid ville have gjort.

## Hvad det kan åbne

| Format | Hvor du møder det |
|---|---|
| SquashFS | Rootfs i næsten al firmware til routere, kameraer og set-top-bokse |
| ext2, ext3, ext4 | Hovedpartitionen på de fleste indlejrede Linux-enheder |
| Btrfs | NAS-diskenheder og nyere Linux-systemer, inklusive snapshots |
| JFFS2, UBIFS | Rå flashhukommelse i ældre og nuværende indlejret hardware |
| cramfs, initramfs | Opstartsfilsystemer og langtidslevende ældre enheder |
| FAT12, FAT16, FAT32 | SD-kort, USB-nøgler og EFI-partitionen på enhver moderne pc |
| exFAT | SD-kort og drev over 32 GB |
| NTFS | Windows-diskenheder, også med komprimerede filer |

## Diskbilleder med flere partitioner

Et billede kopieret fra en hel enhed har som regel en partitionstabel frem for ét enkelt filsystem. Sådan et billede åbner som én mappe pr. partition — `1-rootfs`, `2-esp` — og du går ind i den, du vil. Både MBR- og GPT-tabeller læses, og hvor tabellen indeholder partitionsnavne, bruges de navne.

En partition, pluginet ikke kan læse, vises alligevel som en tom mappe opkaldt efter sin type. Har en enhed tre partitioner, skal du kunne se, at den har tre.

## Firmware uden partitionstabel

En firmwarefil hentet ud af en router eller et kamera har som regel slet ingen partitionstabel. Den er et producenthoved, en bootloader, en kerne og et rootfs skrevet efter hinanden på positioner, der ikke står nogen steder. Sådan en fil åbner med én post pr. del, hver opkaldt efter den position, den begynder på: `0x00230044-squashfs` er et filsystem at gå ind i, `0x00030040-kernel.uimage` en fil at kopiere ud.

![Et panel inde i en routers firmwarefil med producenthovedet, U-Boot-kernen og SquashFS-rodfilsystemet, hver opkaldt efter den position, de begynder på](screenshots/filesystem-images-carved.png)

Delene findes ved at gennemsøge filen for selve filsystemerne og åbne hvert fund for at se, om der virkelig ligger et. Et bytemønster, der passer tilfældigt, koster et øjeblik og kasseres i stedet for at blive til en opdigtet post; og en fil, hvori der ikke findes noget filsystem, afvises stadig og åbner, som den altid ville have gjort.

Det samme gælder alt, hvad der ligger uden for partitionerne i et partitioneret billede. En Raspberry Pi holder sin bootloader i de megabyte, der ligger før partition 1, og U-Boot sidder på de fleste ARM-kort på en fast position i netop den ikke-tildelte plads. De strækninger vises ved siden af partitionerne, så du kan se dem og kopiere dem ud.

## At skrive opbygningen ned

**Kommandoer ▸ Analysér diskbilledets opbygning** gemmer resultatet som en tekstfil ved siden af billedet og sætter markøren på den: hvert område med sin position, sin størrelse og det, det viste sig at være, plus partitionstabellen, hvis billedet har en. Netop den tabel er som regel dét, en gennemgang eller en sag skal bruge, og at bygge den op igen ved at gå et panel igennem og skrive tal af er kedeligt arbejde.

Rapporten viser desuden det, panelet udelader — de små justeringshuller mellem partitioner, for eksempel — og nævner det kort, en U-Boot-kerne er bygget til, når billedet noterer det.

## At arbejde inde i et billede

Alt det, du kender i forvejen, gælder. F3 viser en fil, F5 kopierer filer ud til en rigtig mappe, og **Find filer** søger i billedets indhold. Du går ud af det, som du forlader et arkiv.

Symbolske links vises med deres navn, og kopierer du et ud, får du en lille tekstfil med linkets mål i stedet for et rigtigt link — et billede må ikke kunne placere et link, der peger hvor som helst på din egen disk.

## Når et billede ikke vil åbne

Pluginet fortæller hvorfor i stedet for at melde en ødelagt fil, for de to fører dig hvert sit sted hen:

- **En Btrfs-diskenhed med RAID0, RAID10, RAID5 eller RAID6**, eller fordelt over flere enheder. Data ligger spredt over diske, og det meste er ikke i den fil, du har.
- **Et råt NAND-dump, der stadig indeholder sit reserveområde.** Der er ikke noget galt med billedet; det blev kopieret med fejlrettelsesbyte og det hele. Kopiér det igen med `nanddump --omitoob`.
- **En krypteret ext4- eller NTFS-diskenhed**, som ikke kan læses uden sine nøgler.
- **Et ext-filsystem, der ikke blev afmonteret rent,** åbner stadig, men med en markeret post øverst i roden, der advarer om, at indholdet kan være forældet. Filsystemet blev kopieret under brug, og de nyeste ændringer ligger i en journal, som dette plugin ikke afspiller. Kør `e2fsck` på en kopi, hvis detaljerne betyder noget.

## Bemærkninger

- Et billede læses én gang og huskes, så det går øjeblikkeligt at gå ind i det igen.
- Meget store billeder læses efter behov frem for at blive indlæst helt; en visning er begrænset til to millioner poster.
- Et billede gennemsøges kun for indlejrede filsystemer, når det hverken har en partitionstabel eller et filsystem i begyndelsen, så et almindeligt billede åbner præcis lige så hurtigt som hidtil.
- Pluginet tilføjer én menukommando og ingen egne indstillinger ud over kontakten, der slår det til.
