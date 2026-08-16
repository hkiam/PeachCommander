---
title: Filsystemsavbilder
slug: filesystem-images
section: Plugins
order: 122
related: [plugins, archives, settings, viewing-files]
---

En filsystemsavbild är en fil som innehåller ett helt filsystem — rootfs från en routeruppdatering, ett SD-kort kopierat byte för byte, avbilden av en enhet du undersöker. Insticksmodulen **Linux Filesystem Images** öppnar en sådan som Peach Commander öppnar ett arkiv: ställ markören på den, tryck på Retur, och panelen står inne i filsystemet. Därifrån fungerar visaren, sökningen och kopieringen precis som i en mapp.

Det skrivs aldrig till en avbild. Insticksmodulen kan bara läsa.

## Slå på den först

Insticksmodulen levereras avstängd. Öppna **Inställningar ▸ Insticksmoduler**, leta upp **Linux Filesystem Images** och slå på den.

Den är avstängd som standard på grund av hur den hittar avbilder. Fast programvara har sällan ett städat namn — filen du söker heter minst lika ofta `firmware.bin`, `rootfs.img` eller bara `dump` som `.squashfs` — så när filändelsen inte säger något tittar insticksmodulen på de första byten för att avgöra saken. Det är precis rätt om du undersöker enhetsavbilder, och bortkastat arbete annars. Att slå på den är ditt sätt att säga vilket av de två som gäller dig.

En fil som visar sig inte vara en avbild lämnas orörd efter den enda blicken och öppnas som den alltid skulle ha gjort.

## Vad den kan öppna

| Format | Var du möter det |
|---|---|
| SquashFS | Rootfs i nästan all fast programvara för routrar, kameror och digitalboxar |
| ext2, ext3, ext4 | Huvudpartitionen på de flesta inbyggda Linux-enheter |
| Btrfs | NAS-volymer och nyare Linux-system, ögonblicksbilder inkluderade |
| JFFS2, UBIFS | Rått flashminne i äldre och nuvarande inbyggd maskinvara |
| cramfs, initramfs | Startfilsystem och långlivade äldre enheter |
| FAT12, FAT16, FAT32 | SD-kort, USB-minnen och EFI-partitionen på varje modern PC |
| exFAT | SD-kort och enheter över 32 GB |
| NTFS | Windows-volymer, även med komprimerade filer |

## Diskavbilder med flera partitioner

En avbild kopierad från en hel enhet har oftast en partitionstabell i stället för ett enda filsystem. En sådan avbild öppnas som en mapp per partition — `1-rootfs`, `2-esp` — och du går in i den du vill. Både MBR- och GPT-tabeller läses, och där tabellen innehåller partitionsnamn används de namnen.

En partition som insticksmodulen inte kan läsa visas ändå, som en tom mapp uppkallad efter sin typ. Har en enhet tre partitioner ska du kunna se att den har tre.

## Fast programvara utan partitionstabell

En fil med fast programvara hämtad ur en router eller en kamera har som regel ingen partitionstabell alls. Den är ett tillverkarhuvud, en starthanterare, en kärna och ett rootfs skrivna efter varandra på positioner som inte är noterade någonstans. En sådan fil öppnas med en post per del, var och en uppkallad efter positionen där den börjar: `0x00230044-squashfs` är ett filsystem att gå in i, `0x00030040-kernel.uimage` en fil att kopiera ut.

![En panel inuti en routers fil med fast programvara: tillverkarhuvudet, U-Boot-kärnan och SquashFS-rotfilsystemet, var och en uppkallad efter positionen där den börjar](screenshots/filesystem-images-carved.png)

Delarna hittas genom att filen genomsöks efter själva filsystemen och varje träff öppnas för att se om det verkligen ligger ett där. Ett bytemönster som råkar stämma kostar ett ögonblick och förkastas i stället för att bli en påhittad post; och en fil där inget filsystem står att finna avvisas fortfarande och öppnas som den alltid skulle ha gjort.

Detsamma gäller allt som ligger utanför partitionerna i en partitionerad avbildning. En Raspberry Pi håller sin starthanterare i megabytena före partition 1, och U-Boot sitter på de flesta ARM-kort på en fast position i samma otilldelade utrymme. Dessa sträckor listas bredvid partitionerna så att du kan se dem och kopiera ut dem.

## Att skriva ner uppbyggnaden

**Kommandon ▸ Analysera avbildningens uppbyggnad** sparar resultatet som en textfil bredvid avbildningen och sätter markören på den: varje område med sin position, sin storlek och det den visade sig vara, plus partitionstabellen om avbildningen har en. Just den tabellen är oftast vad en genomgång eller ett ärende behöver, och att bygga upp den igen genom att gå igenom en panel och skriva av tal är tråkigt arbete.

Rapporten visar också det som panelen utelämnar — de små justeringsluckorna mellan partitioner, till exempel — och namnger kortet som en U-Boot-kärna byggts för, när avbildningen noterar det.

## Att arbeta inuti en avbild

Allt du redan kan gäller. F3 visar en fil, F5 kopierar filer ut till en riktig mapp, och **Sök filer** söker i avbildens innehåll. Du går ut ur den som du lämnar ett arkiv.

Symboliska länkar visas med sitt namn, och kopierar du ut en får du en liten textfil med länkens mål i stället för en riktig länk — en avbild får inte tillåtas placera en länk som pekar var som helst på din egen disk.

## När en avbild inte öppnas

Insticksmodulen säger varför i stället för att rapportera en trasig fil, eftersom de två leder dig till olika ställen:

- **En Btrfs-volym med RAID0, RAID10, RAID5 eller RAID6**, eller utspridd över flera enheter. Data ligger spritt över diskar och det mesta finns inte i filen du har.
- **En rå NAND-dump som fortfarande innehåller sitt reservområde.** Det är inget fel på avbilden; den kopierades med felrättningsbyten kvar. Kopiera den igen med `nanddump --omitoob`.
- **En krypterad ext4- eller NTFS-volym**, som inte går att läsa utan sina nycklar.
- **Ett ext-filsystem som inte kopplades från rent** öppnas ändå, men med en markerad post högst upp i roten som varnar för att innehållet kan vara inaktuellt. Filsystemet kopierades medan det användes, och de senaste ändringarna ligger i en journal som den här insticksmodulen inte spelar upp. Kör `e2fsck` på en kopia om detaljerna spelar roll.

## Anmärkningar

- En avbild läses en gång och kommer ihåg, så att gå in i den igen sker omedelbart.
- Mycket stora avbilder läses efter behov i stället för att laddas i sin helhet; en lista är begränsad till två miljoner poster.
- En avbildning genomsöks efter inbäddade filsystem endast när den varken har en partitionstabell eller ett filsystem i början, så en vanlig avbildning öppnas precis lika snabbt som förut.
- Insticksmodulen lägger till ett menykommando och inga egna inställningar utöver reglaget som slår på den.
