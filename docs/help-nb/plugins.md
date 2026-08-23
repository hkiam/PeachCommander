---
title: Programtillegg
slug: plugins
section: Programtillegg
order: 120
related: [disk-map, ai-assistant, git, system-monitor, task-manager, uninstaller, filesystem-images, archives, ftp-and-sftp]
---

Programtillegg utvider Peach Commander med ekstra verktøy, filformater og steder å bla i. Et dusin programtillegg er innebygd, så du kan begynne å bruke dem med en gang, og du kan slå enkelte programtillegg på eller av – eller installere nye – fra ett enkelt vindu. Bruk programtillegg når du vil ha muligheter utover daglig kopiering og bla: visualisere hva som fyller en disk, koble til en WebDAV-server, sjekke tilstanden til et Git-depot, overvåke systemaktivitet og mer.

Programtillegg finnes i noen få varianter: noen legger til et **panel eller sidefelt** (en visning), noen legger til **kolonner** i fillisten, noen legger til et **sted du navigerer inn i** som en stasjon, og noen lærer appen et nytt **arkivformat**. Hvert aktiveres uavhengig.

## Hva de innebygde programtilleggene legger til

Flere programtillegg har sitt eget detaljerte hjelpeemne – følg lenken for hele historien:

- **[Disk Map](disk-map.md)** – visualiserer hva som fyller en mappe eller et volum som et trekart eller en solstråle, avstemt mot ledig, ryddbar og skjult plass, med en oppryddingssamler.
- **[AI Assistant](ai-assistant.md)** – en valgfri assistent du kan fjerne, som oppsummerer, gir nytt navn til, oversetter, tabellerer og rydder filer i vanlig språk, på enheten eller via en skymodell.
- **[Git](git.md)** – viser hver fils status i arbeidstreet og gjeldende gren som panelkolonner, og legger til en **Git**-meny for status, klargjøring, innsjekking, pull og push.
- **[System Monitor](system-monitor.md)** – en sanntidsavlesning av CPU, minne, disk, nettverk (og, der tilgjengelig, GPU, batteri, sensorer) i vinduets tittellinje, med detaljgrafer du kan klikke deg inn på.
- **[Task Manager](task-manager.md)** – monterer prosessene dine som kjører som en **TaskManager**-stasjon du kan bla i; sorter dem, gransk dem som filer, eller avslutt dem med Slett.
- **[Filsystemavbilder](filesystem-images.md)** — åpner en filsystemavbild (SquashFS, ext, Btrfs, JFFS2, UBIFS, cramfs, initramfs, FAT, exFAT, NTFS) som et arkiv, også diskavbilder med flere partisjoner. Bare lesing, og avslått til du slår det på.
- **[Uninstaller](uninstaller.md)** – fjerner et program **og** støttefilene, hurtiglagrene og innstillingene det etterlater seg, etter å ha vist deg nøyaktig hva som forsvinner.

De resterende innebygde programtilleggene er mindre og trenger ikke en egen side:

- **Amazon S3** — koble til Amazon S3 eller S3-kompatibel lagring (**Nett ▸ Koble til Amazon S3…**) og utforsk buckets som mapper, med lesing, skriving, navneendring og sletting. Hemmelige nøkler oppbevares i macOS-nøkkelringen.
- **WebDAV** – koble til en WebDAV-server (**Nettverk ▸ WebDAV-tilkobling…**) og bla, last opp, last ned, gi nytt navn og slett på den som om den var en mappe. Passord holdes i macOS-nøkkelringen.
- **iCloud** – legger til en *iCloud Drive*-oppføring i stasjonslinjen som hopper rett til din lokale iCloud Drive-mappe. Den vises bare når iCloud Drive er satt opp på Mac-en din.
- **Notes** – behold et notat ved siden av en hvilken som helst fil eller mappe. Et lite **●**-merke markerer elementer som har ett; rediger notater i et forankret **Notes**-sidefelt eller en fullstendig rik-tekst-redigerer (**Kommandoer ▸ Rediger notat…**), og bla gjennom dem alle med **Notatoversikt…**.
- **Log Viewer** – åpne en fil som en fargekodet, nivåklassifisert logg med sanntidsfølging (**Fil ▸ Vis som logg…**), med filtre per nivå, søk og støtte for vanlige loggformater pluss dine egne regex-formater. Håndterer logger på flere gigabyte umiddelbart.
- **CSV Lister** — trykk F3 på en `.csv`- eller `.tsv`-fil, og den åpnes som en ekte tabell med sorterbare kolonner i stedet for rå tekst. Skilletegnet oppdages automatisk, så semikolonseparerte eksporter stiller seg også opp, og viserens søk finner verdier celle for celle.
- **AI Column** – legger til en *AI Language*-kolonne som oppdager hver tekstfils dominerende språk på enheten (ved hjelp av Apples NaturalLanguage-rammeverk – ikke en skymodell).
- **Arkivformater** – lærer appen å bla i og pakke ut flere arkivtyper (7z, tar-familien, gzip/bzip2/xz/zstd, og RAR der et hjelpeverktøy er installert), som deretter åpnes som mapper.

## Slå programtillegg på eller av

1. Velg Konfigurasjon ▸ Programtillegg… for å åpne programtilleggsvinduet.
2. Hvert installerte programtillegg vises i listen med navn, type og en «Aktivert»-avkrysningsrute.
3. Merk eller fjern merket i ruten for å aktivere eller deaktivere et programtillegg. Endringer trer i kraft med en gang – aktiverte programtillegg legger til menyene, kolonnene og funksjonene sine; deaktiverte holder seg unna.

![Programtilleggsvinduet som lister installerte programtillegg med avkrysningsruter og knappene Installer og Fjern](screenshots/plugins-window.png)
*(Figur: Programtilleggsvinduet, der du aktiverer, deaktiverer, installerer eller fjerner programtillegg.)*

## Installer et nytt programtillegg

1. Velg Konfigurasjon ▸ Programtillegg….
2. Klikk på **Installer fra mappe…**.
3. Velg en programtilleggspakke eller en `.zip` som inneholder en, og bekreft. Programtillegget legges til i listen og aktiveres.

## Fjern et programtillegg

1. I programtilleggsvinduet, merk programtillegget i listen.
2. Klikk på **Fjern**. Innebygde funksjoner påvirkes ikke; bare det valgte programtillegget fjernes.

## Merknader

- Programtilleggslisten viser hvert programtilleggs type og grensesnittsversjon ved siden av navn og plassering, så du kan bekrefte hva som er installert.
- Hvis ingen programtillegg er installert, viser vinduet en kort oppfordring som peker deg mot **Installer fra mappe…**.
- Noen programtillegg legger til sine egne kolonner, menyvalg eller panelsteder bare mens de er aktivert. Om en funksjon du forventet mangler, sjekk at programtillegget er slått på her.
