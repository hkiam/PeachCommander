---
title: Task Manager
slug: task-manager
section: Plug-ins
order: 125
related: [plugins, viewing-files, deleting-files]
---

De Task Manager-plug-in verandert de actieve processen op je Mac in een map die je kunt doorbladeren. Hij verschijnt als een **TaskManager**-schijf in de schijvenbalk; open hem en elk proces is een rij die je kunt sorteren, als een bestand inspecteren of beëindigen — met dezelfde toetsen die je al voor bestanden gebruikt. Het is een plug-in, dus je kunt hem uitschakelen of verwijderen via **Configuratie ▸ Plug-ins…**.

## Openen

1. Klik op de **📊 TaskManager**-vermelding in de schijvenbalk (die staat direct na je startschijf).
2. Het paneel vult zich met één rij per actief proces. De naam van elke rij is de procesnaam gevolgd door de PID, bijvoorbeeld `Finder (462)`.
3. De knop **TaskManager** blijft geselecteerd zolang je erin zit en het tabblad krijgt de naam van de schijf. Ga naar een ander tabblad en terug — of sluit de app en open hem opnieuw — en het tabblad toont weer de proceslijst. Om het te verlaten ga je één niveau omhoog of klik je op een ander volume in de schijvenbalk.

![Task Manager toont actieve processen met de kolommen PID, CPU, geheugen en command](screenshots/task-manager.png)
*(Afbeelding: actieve processen getoond als een bestandslijst die je kunt sorteren en waarop je kunt handelen.)*

## Wat elke kolom betekent

Naast de kolom Datum (starttijd) voegt Task Manager proceskolommen toe. De Grootte van een procesrij toont `DIR`, omdat een proces een map is die u kunt openen (zie hieronder) — het geheugen heeft eigen kolommen:

| Kolom | Betekenis |
| --- | --- |
| **PID** | Proces-id |
| **CPU %** | Recent processorgebruik (verschijnt pas na een tweede vernieuwing) |
| **Memory** | Geheugenvoetafdruk — waarvoor dit proces verantwoordelijk is (het getal dat Activiteitenweergave toont) |
| **Resident** | Residente grootte, gedeelde pagina's inbegrepen; voor elk proces ingevuld |
| **Threads** | Aantal threads |
| **State** | R actief · S slapend · T gestopt · Z zombie · I inactief, plus de achtervoegsels die `ps` toevoegt (s = sessieleider, + = voorgrond, N = lage prioriteit) |
| **User** | Eigenaar |
| **PPID** | Proces-id van de ouder |
| **Read** | Bytes van de schijf gelezen sinds het proces startte |
| **Written** | Bytes naar de schijf geschreven sinds het proces startte |
| **Wakeups** | Interrupt-wekmomenten sinds het proces startte |
| **Signed** | Wie het programma ondertekende: Apple, een Developer ID-team, ad-hoc of niet ondertekend |
| **Command** | Volledige opdrachtregel |

Sorteer op elke kolom (bijvoorbeeld CPU % of Grootte/geheugen), net zoals je in een gewone map zou doen.

## Een proces inspecteren of beëindigen

- **Bekijken (F3)** toont een rapport *Process Information*: naam, PID, ouder, gebruiker, status, threads, geheugen, CPU, starttijd, pad naar het uitvoerbare bestand en de volledige opdrachtregel.
- **Verwijderen (F8)** beëindigt het proces. De eerste verwijdering stuurt een nette **quit** (SIGTERM); een proces dat nog draait een tweede keer verwijderen escaleert naar een **force quit** (SIGKILL). De plug-in richt zich nooit op PID 1.

## De processen vinden die een bestand gebruiken

Klik met de rechtermuisknop op een willekeurige rij en kies **Processen zoeken op bestand…**, voer daarna het pad van een bestand in. Elk proces dat dat bestand op dat moment geopend heeft, wordt gemarkeerd en de cursor springt naar het eerste proces dat het kan wijzigen:

- **Blauw** — het proces leest het bestand alleen.
- **Oranje** — het proces schrijft er alleen naar.
- **Paars** — het proces doet beide.

Het pad wordt vooringevuld vanaf de cursor in het andere paneel, zodat u daar een bestand kunt aanwijzen en zonder typen kunt vragen. **Proces zoeken op poort…** in hetzelfde menu beantwoordt de verwante vraag: welk proces op een TCP/UDP-poort luistert. Kies **Bestandsmarkering wissen** om de kleuren te verwijderen; het verlaten van de proceslijst verwijdert ze eveneens.

## Open een proces om zijn bestanden te zien

Druk op Enter op een proces — of dubbelklik erop — en het paneel toont de bestanden die dat proces op dat moment geopend heeft, als gewone bestandsrijen met hun echte grootte en datum. Vandaar:

- **Bekijken (F3)** opent het bestand zelf.
- **Ga naar bestand** toont het in het andere paneel, waar u ermee kunt werken.
- **Toon in Finder** geeft het door aan de Finder.

Alleen geopende bestanden tellen: een bibliotheek die het proces alleen in het geheugen heeft geladen, en zijn werkmap, zijn geen geopende bestanden. Het proces van een andere gebruiker toont een lege map.

## Opmerkingen

- Basisgegevens (PID, ouder, gebruiker, status, ondertekening) zijn voor elk proces leesbaar. Geheugenvoetafdruk, threads, schijf-I/O en de lijst met geopende bestanden zijn leesbaar voor **uw eigen** processen, wat op een gewone Mac het grootste deel van de lijst is. Voor processen van andere gebruikers worden CPU en Resident in plaats daarvan uit `ps` gevuld — een gemiddelde over de hele levensduur in plaats van het verschil tussen twee metingen dat de andere rijen dragen — en threads en voetafdruk blijven leeg.
- CPU % is een verschil tussen twee metingen, dus het blijft leeg tot het paneel een tweede keer wordt vernieuwd (het paneel vernieuwt ongeveer elke twee seconden).
- De lijst is alleen-lezen, afgezien van het beëindigen van een proces — je kunt er geen bestanden naartoe kopiëren.
- De markeringskleuren volgen uw kleurthema: het Norton-palet gebruikt in plaats daarvan groen, rood en magenta.
- Alleen handles die uw account mag inzien worden gevonden, wat in de praktijk uw eigen processen betekent. Een bibliotheek die een proces alleen in het geheugen heeft geladen, of zijn werkmap, is geen open handle en wordt niet gemeld.
- De kolom **Signed** vult zich in de eerste seconden: een handtekening lezen duurt ongeveer een milliseconde en er zijn honderden verschillende programma's, dus er worden er per verversing een paar gelezen en daarna onthouden. Een lege cel betekent “nog niet gelezen”, niet “niet ondertekend”.
- **Signed** zegt wie het programma ondertekende, niet of het genotariseerd is: notarisatie controleren betekent het hele programma hashen, wat per programma seconden zou kosten.
- Het snelfilter (Ctrl+S) treft hier ook de kolommen en niet alleen de naam, en een term kan de kolom noemen waarvoor hij geldt: `user:root state:R` vraagt wat root op dit moment draait. Termen worden gescheiden door spaties en moeten allemaal kloppen; tekst die geen kolom noemt, blijft één gewone deeltekst, spaties inbegrepen.
