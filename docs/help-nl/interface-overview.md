---
title: Het hoofdvenster
slug: interface-overview
section: Aan de slag
order: 12
related: [navigating, panels-and-tabs]
---

Peach Commander toont twee bestandslijsten naast elkaar, zodat je tegelijk kunt zien waar bestanden vandaan komen en waar ze naartoe gaan. Het meeste van je werk gebeurt in deze twee panelen; met de balken eromheen kun je van schijf wisselen, naar een map springen en de gangbare bestandsopdrachten uitvoeren zonder het toetsenbord te verlaten. Deze rondleiding benoemt elk deel van het venster, zodat de rest van de help logisch wordt.

![Het hoofdvenster van Peach Commander met zijn twee panelen en omringende balken](screenshots/main-window.png)
*(Afbeelding: Het hoofdvenster — twee panelen met de knoppenbalk, schijfbalk en padbalken erboven en de functietoetsenbalk eronder.)*

## De twee panelen en het actieve paneel

Het venster is opgesplitst in een linkerpaneel en een rechterpaneel, elk met de inhoud van één map. Slechts één paneel is tegelijk actief: het toont de cursor (een gemarkeerde rij) en zijn padbalk heeft een gekleurde achtergrond. Opdrachten zoals kopiëren en verplaatsen werken altijd op het actieve paneel en sturen bestanden naar het andere.

1. Klik ergens in een paneel om het actief te maken, of druk op Tab om ertussen te wisselen.
2. Gebruik de pijltoetsen om de cursor omhoog en omlaag in het actieve paneel te bewegen.
3. Druk op Enter op een map om die te openen, of op `..` boven aan de lijst om een niveau omhoog te gaan.

## Balken rond de panelen

- **Knoppenbalk** (boven): een rij platte knoppen voor veelgebruikte opdrachten. Klik op een knop om de opdracht uit te voeren; klik met de rechtermuisknop op een knop om de balk te bewerken.
- **Schijvenbalk**: één knop per beschikbare schijf of volume, elk met de vrije ruimte. Klik op een volume om dat paneel ernaartoe te schakelen; klik er met rechts op om het uit te werpen — aangeboden voor verwisselbare volumes en gekoppelde schijfkopieën, grijs voor de opstartschijf en netwerkschijven.
- **Padbalk**: toont de huidige map als een klikbaar broodkruimelpad. Klik op een segment om direct naar die map te springen, of klik op het pad om een locatie te typen.
- **Statusbalk** (onder elke lijst): een doorlopende samenvatting van het paneel — hoeveel bestanden en mappen geselecteerd zijn en hun totale grootte.
- **Opdrachtregel** (onderaan): een tekstveld waarin je een shell-achtige opdracht kunt typen die in de huidige map wordt uitgevoerd.
- **Functietoetsenbalk** (helemaal onderaan): zes knoppen met de labels F3 Bekijken, F4 Bewerken, F5 Kopiëren, F6 Verplaatsen, F7 NieuweMap en F8 Verwijderen. Klik op een knop of druk op de bijbehorende toets.

![Uitsnede van de schijfbalk met volumeknoppen en vrije ruimte](screenshots/drive-bar-crop.png)
*(Afbeelding: de schijvenbalk — één knop per volume, met de resterende vrije ruimte; klik met rechts op een volume om het uit te werpen.)*

## Sneltoetsen

| Actie | Sneltoets |
|---|---|
| Wissel van actief paneel | Tab |
| Open map / item onder cursor | Enter |
| Ga een map omhoog | Backspace |
| Bestand bekijken | F3 |
| Bestand bewerken | F4 |
| Kopiëren naar ander paneel | F5 |
| Verplaatsen / hernoemen naar ander paneel | F6 |
| Nieuwe map | F7 |
| Verwijderen (naar Prullenmand) | F8 |

## Opmerkingen

- De functietoetsenbalk wijzigt zijn labels live wanneer je een modificatietoets ingedrukt houdt. Als je bijvoorbeeld Shift ingedrukt houdt, verandert F6 in een actie voor hernoemen ter plaatse, zodat de knoppen altijd tonen wat de toetsen op dat moment doen.
- Bijna elke balk kan worden getoond of verborgen. Kijk onder de menu's Weergave en Configuratie om de knoppenbalk, schijfbalk, opdrachtregel of functietoetsenbalk aan en uit te zetten, of om de twee panelen boven en onder elkaar te stapelen in plaats van naast elkaar.
- Op veel Mac-toetsenborden fungeren de F-toetsen standaard als bedieningsknoppen voor media en helderheid. Houd de Fn-toets samen met F3-F8 ingedrukt, of zet "Gebruik F1-, F2- en andere toetsen als standaardfunctietoetsen" aan in Systeeminstellingen, om ze direct te gebruiken.
