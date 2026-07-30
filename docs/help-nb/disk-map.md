---
title: Diskkart
slug: disk-map
section: Programtillegg
order: 121
related: [plugins, deleting-files, settings]
---

Diskkart er et innebygd programtillegg som med ett blikk viser hva som bruker plass i en mappe eller på et helt volum. Det skanner mappen du velger og tegner hvert element i størrelse proporsjonalt med plassen det faktisk opptar på disken, slik at de største plassslukerne skiller seg ut umiddelbart. Du kan bore deg inn i mapper, se hvordan skanningen din stemmer overens med volumets ledige, tømbare og skjulte plass, og rydde opp rett fra kartet.

## Start en skanning

1. I det aktive panelet går du til mappen (eller volumet) du vil måle.
2. Velg **Kommandoer ▸ Diskkart: Analyser gjeldende mappe**.
3. Diskkart-visningen åpnes til høyre og skanner i bakgrunnen, og viser en løpende telling av elementer og bytes. Store mapper blir ferdige på noen få sekunder — skanningen leser katalogmetadata i bulk og arbeider på tvers av flere CPU-kjerner.

![Diskkartet som viser et kvadratisert tremapp av en mappe, en volumlinje, en liste over de største filene og en kategoriforklaring](screenshots/disk-map.png)
*(Figur: Tremapp-visningen, farget etter filkategori, med volumlinjen på toppen og listen over de største filene til høyre.)*

## Les kartet

- Hver blokk (tremapp) eller ringsegment (soleksplosjon) har størrelse etter elementets **faktiske størrelse på disken**, så bildet stemmer med det Finder og systemet rapporterer.
- Blokker er **farget etter filtype** — video, bilder, lyd, dokumenter, kode, arkiver, apper, diskbilder — med en forklaring langs bunnen. Du kan bytte til et størrelses-**varmekart** i innstillingene.
- **Klikk på en mappe** for å bore deg inn i den; smulestien øverst viser hvor du er, og **◂**-knappen går tilbake opp.
- Hold pekeren over en hvilken som helst blokk for å se dens fulle sti, størrelse og elementantall.

## To visninger: tremapp og soleksplosjon

Diskkart tilbyr to visualiseringer, og du kan bytte mellom dem med **◎ / ▦**-knappen i overskriften eller på innstillingssiden:

- **Tremapp** — nestede rektangler, tettest for å oppdage de enkeltvis største filene.
- **Soleksplosjon** — konsentriske ringer (én per mappedybde) rundt gjeldende mappe, best for å se hvordan plass er fordelt over et dypt tre.

![Diskkartets soleksplosjonsvisning som viser konsentriske ringer for mappedybde](screenshots/disk-map-sunburst.png)
*(Figur: Soleksplosjonsvisningen — den indre skiven er gjeldende mappe og hver ring er ett nivå dypere.)*

## Volumlinjen

Linjen på toppen stemmer skanningen din av mot hele volumet:

- **Skannet / Denne mappen** — hvor mye den analyserte mappen opptar.
- **Skjult** (ved volumroten) eller **Resten av volumet** (for en undermappe) — alt som ikke er i denne skanningen, inkludert systembeskyttede mapper, andre brukere og øyeblikksbilder.
- **Tømbar** — plass macOS kan gjenvinne automatisk, for det meste lokale Time Machine-øyeblikksbilder og hurtiglagre.
- **Ledig** — plass tilgjengelig akkurat nå.

Når volumet har lokale øyeblikksbilder, viser linjen en **· N øyeblikksbilder (ⓘ)**-funksjon; klikk på den for en skrivebeskyttet liste, med et hint om å administrere dem i Diskverktøy eller Time Machine. Diskkart sletter aldri øyeblikksbilder selv.

## Største filer

Slå på **Vis listen over de største filene** for å se de største filene i gjeldende mappe rangert etter størrelse, hver med en fargebrikke for sin kategori. Klikk på en for å utheve den på kartet.

## Rydd opp fra kartet

Høyreklikk på en hvilken som helst blokk for handlinger:

- **Åpne i venstre panel** / **Åpne i høyre panel** — vis elementet i et filpanel.
- **Vis i Finder**.
- **Flytt til Papirkurv** — slett bare det elementet; kartet oppdateres uten en full ny skanning.

For å fjerne flere elementer på én gang, bruk **Samleren**: høyreklikk ▸ **Merk for Samleren** på hvert element, og klikk deretter **🗑 N**-knappen i overskriften for å flytte alt du merket til Papirkurven i ett bekreftet steg.

## Innstillinger

Diskkart legger til sin egen side i Innstillinger-vinduet (**Konfigurasjon ▸ Innstillinger ▸ Diskkart**):

- **Diagramstil** — tremapp eller soleksplosjon.
- **Fargekoding** — etter filtype (kategori) eller etter størrelse (varmekart).
- **Bli på startvolumet** — ikke kryss over til andre monterte disker.
- **Vis volumlinjen** og **Vis listen over de største filene**.

Endringer trer i kraft på et åpent Diskkart umiddelbart.

## Merknader

- Diskkart måler **allokert** størrelse (på disken) og teller **hardlenkede** filer bare én gang, slik at totalene stemmer overens med volumets brukte plass i stedet for å telle for mye.
- Som standard blir skanningen på startvolumet, så den vandrer ikke inn i andre monterte disker eller nettverksdelinger.
