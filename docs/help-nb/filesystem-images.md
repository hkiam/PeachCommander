---
title: Filsystemavbilder
slug: filesystem-images
section: Plugins
order: 122
related: [plugins, archives, settings, viewing-files]
---

En filsystemavbild er en fil som inneholder et helt filsystem — rootfs fra en ruteroppdatering, et SD-kort kopiert byte for byte, avbildet av en enhet du undersøker. Programtillegget **Linux Filesystem Images** åpner en slik slik Peach Commander åpner et arkiv: sett markøren på den, trykk Enter, og panelet står inne i filsystemet. Derfra virker viseren, søket og kopieringen nøyaktig som i en mappe.

Det skrives aldri til en avbild. Programtillegget kan bare lese.

## Slå det på først

Programtillegget leveres avslått. Åpne **Innstillinger ▸ Programtillegg**, finn **Linux Filesystem Images**, og slå det på.

Det er avslått som standard på grunn av måten det finner avbilder på. Fastvare har sjelden et ryddig navn — filen du leter etter heter minst like ofte `firmware.bin`, `rootfs.img` eller bare `dump` som `.squashfs` — så når filendelsen ikke sier noe, ser programtillegget på de første bytene for å avgjøre det. Det er akkurat riktig hvis du undersøker enhetsavbilder, og bortkastet arbeid ellers. Å slå det på er måten du sier hvilken av de to du er.

En fil som viser seg ikke å være en avbild, blir liggende urørt etter det ene blikket og åpnes slik den alltid ville gjort.

## Hva det kan åpne

| Format | Hvor du møter det |
|---|---|
| SquashFS | Rootfs i nesten all fastvare til rutere, kameraer og dekodere |
| ext2, ext3, ext4 | Hovedpartisjonen på de fleste innebygde Linux-enheter |
| Btrfs | NAS-volumer og nyere Linux-systemer, øyeblikksbilder inkludert |
| JFFS2, UBIFS | Rått flashminne i eldre og nåværende innebygd maskinvare |
| cramfs, initramfs | Oppstartsfilsystemer og langlivede eldre enheter |
| FAT12, FAT16, FAT32 | SD-kort, USB-pinner og EFI-partisjonen på enhver moderne PC |
| exFAT | SD-kort og stasjoner over 32 GB |
| NTFS | Windows-volumer, også med komprimerte filer |

## Diskavbilder med flere partisjoner

En avbild kopiert fra en hel enhet har som regel en partisjonstabell i stedet for ett enkelt filsystem. En slik avbild åpnes som én mappe per partisjon — `1-rootfs`, `2-esp` — og du går inn i den du vil. Både MBR- og GPT-tabeller leses, og der tabellen inneholder partisjonsnavn, brukes de navnene.

En partisjon programtillegget ikke kan lese, vises likevel som en tom mappe oppkalt etter typen sin. Har en enhet tre partisjoner, skal du kunne se at den har tre.

## Fastvare uten partisjonstabell

En fastvarefil hentet ut av en ruter eller et kamera har som regel ingen partisjonstabell i det hele tatt. Den er et produsenthode, en oppstartslaster, en kjerne og et rootfs skrevet etter hverandre på posisjoner som ikke er notert noe sted. En slik fil åpnes med én oppføring per del, hver oppkalt etter posisjonen den begynner på: `0x00230044-squashfs` er et filsystem å gå inn i, `0x00030040-kernel.uimage` en fil å kopiere ut.

![Et panel inne i en ruters fastvarefil med produsenthodet, U-Boot-kjernen og SquashFS-rotfilsystemet, hver oppkalt etter posisjonen de begynner på](screenshots/filesystem-images-carved.png)

Delene finnes ved å søke gjennom filen etter selve filsystemene og åpne hvert treff for å se om det virkelig ligger et der. Et bytemønster som treffer tilfeldig, koster et øyeblikk og forkastes i stedet for å bli en oppdiktet oppføring; og en fil der det ikke finnes noe filsystem, avvises fortsatt og åpnes slik den alltid ville ha gjort.

Det samme gjelder alt som ligger utenfor partisjonene i et partisjonert avtrykk. En Raspberry Pi holder oppstartslasteren sin i megabytene foran partisjon 1, og U-Boot sitter på de fleste ARM-kort på en fast posisjon i den samme utildelte plassen. Disse strekningene listes ved siden av partisjonene, slik at du kan se dem og kopiere dem ut.

## Å skrive ned oppbygningen

**Kommandoer ▸ Analyser oppbygningen av avtrykket…** lagrer resultatet som en tekstfil ved siden av avtrykket og setter markøren på den: hvert område med sin posisjon, sin størrelse og det det viste seg å være, pluss partisjonstabellen dersom avtrykket har en. Nettopp den tabellen er som regel det en gjennomgang eller en sak trenger, og å bygge den opp igjen ved å gå gjennom et panel og skrive av tall er kjedelig arbeid.

Rapporten viser også det panelet utelater — de små justeringshullene mellom partisjoner, for eksempel — og navngir kortet en U-Boot-kjerne er bygget for, når avtrykket noterer det.

## Å arbeide inne i en avbild

Alt du allerede kan, gjelder. F3 viser en fil, F5 kopierer filer ut til en ekte mappe, og **Finn filer** søker i innholdet i avbilden. Du går ut av den slik du forlater et arkiv.

Symbolske lenker vises med navnet sitt, og kopierer du en ut, får du en liten tekstfil med lenkens mål i stedet for en ekte lenke — en avbild kan ikke få lov til å plassere en lenke som peker hvor som helst på din egen disk.

## Når en avbild ikke åpnes

Programtillegget sier hvorfor i stedet for å melde om en ødelagt fil, for de to fører deg til hvert sitt sted:

- **Et Btrfs-volum med RAID0, RAID10, RAID5 eller RAID6**, eller fordelt over flere enheter. Dataene ligger spredt over disker, og det meste er ikke i filen du har.
- **En rå NAND-dump som fortsatt inneholder reserveområdet sitt.** Det er ingenting galt med avbilden; den ble kopiert med feilrettingsbytene og alt. Kopier den på nytt med `nanddump --omitoob`.
- **Et kryptert ext4- eller NTFS-volum**, som ikke kan leses uten nøklene sine.
- **Et ext-filsystem som ikke ble koblet fra rent** åpnes fortsatt, men med en merket oppføring øverst i roten som advarer om at innholdet kan være utdatert. Filsystemet ble kopiert mens det var i bruk, og de nyeste endringene ligger i en journal dette programtillegget ikke spiller av. Kjør `e2fsck` på en kopi hvis detaljene betyr noe.

## Merknader

- En avbild leses én gang og huskes, så det går umiddelbart å gå inn i den igjen.
- Svært store avbilder leses etter behov i stedet for å lastes inn i sin helhet; en liste er begrenset til to millioner oppføringer.
- Et avtrykk gjennomsøkes for innebygde filsystemer bare når det verken har en partisjonstabell eller et filsystem i starten, så et vanlig avtrykk åpnes akkurat like raskt som før.
- Programtillegget legger til én menykommando og ingen egne innstillinger utover bryteren som slår det på.
