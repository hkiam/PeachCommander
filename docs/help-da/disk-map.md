---
title: Diskkort
slug: disk-map
section: Plugins
order: 121
related: [plugins, deleting-files, settings]
---

Diskkort er et indbygget plugin, der med et enkelt blik viser, hvad der bruger plads i en mappe eller på en hel diskenhed. Det scanner den mappe, du vælger, og tegner hvert emne i en størrelse, der er proportional med den plads, det faktisk optager på disken, så de største pladsslugere skiller sig ud med det samme. Du kan bore ned i mapper, se hvordan din scanning stemmer overens med diskenhedens frie, rensbare og skjulte plads og rydde op direkte fra kortet.

## Start en scanning

1. Gå i det aktive panel til den mappe (eller diskenhed), du vil måle.
2. Vælg **Kommandoer ▸ Diskkort: Analysér aktuel mappe**.
3. Diskkort-visningen åbner til højre og scanner i baggrunden, mens den viser en løbende optælling af emner og bytes. Store mapper bliver færdige på nogle få sekunder — scanningen læser mappemetadata i massevis og arbejder på tværs af flere CPU-kerner.

![Diskkortet viser et kvadreret trækort over en mappe, en diskenhedsbjælke, en liste over de største filer og en kategoriforklaring](screenshots/disk-map.png)
*(Figur: Trækortvisningen, farvet efter filkategori, med diskenhedsbjælken øverst og listen over de største filer til højre.)*

## Læs kortet

- Hver blok (trækort) eller ringsegment (solstråle) har en størrelse efter emnets **faktiske størrelse på disken**, så billedet matcher det, Finder og systemet rapporterer.
- Blokke er **farvet efter filtype** — video, billeder, lyd, dokumenter, kode, arkiver, apps, diskbilleder — med en forklaring langs bunden. Du kan skifte til et **varmekort** efter størrelse i indstillingerne.
- **Klik på en mappe** for at bore ned i den; brødkrummestien øverst viser, hvor du er, og knappen **◂** går et trin op igen.
- Hold markøren over enhver blok for at se dens fulde sti, størrelse og antal emner.

## To visninger: trækort og solstråle

Diskkort tilbyder to visualiseringer, og du kan skifte mellem dem med knappen **◎ / ▦** i overskriften eller på indstillingssiden:

- **Trækort** — indlejrede rektangler, tættest til at få øje på den enkelte største fil.
- **Solstråle** — koncentriske ringe (én pr. mappedybde) omkring den aktuelle mappe, bedst til at se, hvordan plads er fordelt på tværs af et dybt træ.

![Diskkortets solstrålevisning med koncentriske ringe for mappedybde](screenshots/disk-map-sunburst.png)
*(Figur: Solstrålevisningen — den inderste skive er den aktuelle mappe, og hver ring er ét niveau dybere.)*

## Diskenhedsbjælken

Bjælken øverst afstemmer din scanning mod hele diskenheden:

- **Scannet / Denne mappe** — hvor meget den analyserede mappe optager.
- **Skjult** (ved diskenhedens rod) eller **Resten af diskenheden** (for en undermappe) — alt, der ikke er i denne scanning, herunder systembeskyttede mapper, andre brugere og øjebliksbilleder.
- **Rensbar** — plads, macOS kan frigøre automatisk, mest lokale Time Machine-øjebliksbilleder og caches.
- **Fri** — plads, der er tilgængelig lige nu.

Når diskenheden har lokale øjebliksbilleder, viser bjælken en **· N øjebliksbilleder (ⓘ)**-funktion; klik på den for en skrivebeskyttet liste med et tip om at håndtere dem i Diskværktøj eller Time Machine. Diskkort sletter aldrig selv øjebliksbilleder.

## Største filer

Slå **Vis listen over de største filer** til for at se de største filer i den aktuelle mappe rangeret efter størrelse, hver med en farvechip for sin kategori. Klik på en for at fremhæve den på kortet.

## Ryd op fra kortet

Højreklik på enhver blok for handlinger:

- **Åbn i venstre panel** / **Åbn i højre panel** — vis emnet i et filpanel.
- **Vis i Finder**.
- **Flyt til papirkurv** — slet kun det emne; kortet opdateres uden en fuld genscanning.

For at fjerne flere emner på én gang skal du bruge **Samleren**: højreklik ▸ **Markér til Samleren** på hvert emne, og klik derefter på knappen **🗑 N** i overskriften for at flytte alt, du har markeret, til papirkurven i ét bekræftet trin.

## Indstillinger

Diskkort tilføjer sin egen side til Indstillinger-vinduet (**Konfiguration ▸ Indstillinger ▸ Diskkort**):

- **Diagramstil** — trækort eller solstråle.
- **Farvekodning** — efter filtype (kategori) eller efter størrelse (varmekort).
- **Bliv på startdiskenheden** — kryds ikke over til andre monterede diske.
- **Vis diskenhedsbjælken** og **Vis listen over de største filer**.

Ændringer anvendes på et åbent Diskkort med det samme.

## Bemærkninger

- Diskkort måler **allokeret** størrelse (på disken) og tæller **hårdt linkede** filer kun én gang, så dets totaler stemmer overens med diskenhedens brugte plads i stedet for at tælle for meget.
- Som standard bliver scanningen på startdiskenheden, så den ikke vandrer ind på andre monterede diske eller netværksdrev.
