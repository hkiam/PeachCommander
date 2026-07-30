---
title: Bestandshulpmiddelen
slug: file-utilities
section: Krachtige hulpmiddelen
order: 94
related: [comparing-and-syncing]
---

Naast kopiëren en verplaatsen bevat Peach Commander een set alledaagse bestandshulpmiddelen om te verifiëren dat bestanden intact zijn, schijfruimte terug te winnen, grote bestanden in kleinere stukken op te breken en bestanden om te zetten naar en van tekstveilige formaten. Je bereikt ze allemaal via het menu **Bestand**, en ze werken op wat je ook geselecteerd hebt in het actieve paneel (of het item onder de cursor wanneer er niets geselecteerd is). Dit onderwerp behandelt controlesommen, de duplicaatzoeker, splitsen/samenvoegen, coderen/decoderen en het berekenen van de bezette ruimte.

## Controlesommen maken of verifiëren

Met controlesommen kun je bevestigen dat een bestand zonder beschadiging is gedownload of gekopieerd, of een ontvanger een manier geven om de kopie die hij heeft ontvangen te controleren.

1. Selecteer de bestanden waarvan je een vingerafdruk wilt maken.
2. Kies **Bestand ▸ Controlesommen maken…**, kies een algoritme (CRC32, MD5, SHA-1, SHA-256 of SHA-512) en bewaar het controlesombestand.
3. Om bestanden later te controleren, selecteer je het controlesombestand en kies je **Bestand ▸ Controlesommen verifiëren…**. Peach Commander herberekent elke hash en rapporteert elk bestand dat niet overeenkomt.

Controlesommen streamen rechtstreeks over de huidige locatie, zodat je ze zelfs kunt maken of verifiëren voor bestanden binnen archieven of op een FTP-server.

## Dubbele bestanden vinden

De duplicaatzoeker vindt identieke bestanden verspreid over mappen zodat je de extra kopieën kunt verwijderen.

1. Selecteer de mappen (of bestanden) die je wilt scannen.
2. Kies **Bestand ▸ Duplicaten zoeken…**. Peach Commander vergelijkt kandidaten en groepeert bestanden die byte voor byte identiek zijn.
3. Bekijk elke groep, markeer de kopieën die je niet meer nodig hebt en verwijder ze.

![De duplicaatzoeker die groepen identieke bestanden weergeeft](screenshots/duplicate-finder.png)
*(Afbeelding: De duplicaatzoeker groepeert identieke bestanden zodat je er één kunt behouden en de rest kunt verwijderen.)*

## Bestanden splitsen en samenvoegen

Splitsen breekt één groot bestand op in een genummerde reeks kleinere delen — handig voor opslag- of overdrachtslimieten. Samenvoegen stelt ze weer samen.

1. Om te splitsen, selecteer je een bestand en kies je **Bestand ▸ Bestand splitsen…**, en stel je vervolgens de deelgrootte in. De delen worden naar de map van het andere paneel geschreven.
2. Om weer samen te stellen, selecteer je het eerste deel en kies je **Bestand ▸ Bestanden samenvoegen…**. Het oorspronkelijke bestand wordt opnieuw opgebouwd uit de genummerde stukken.

## Coderen en decoderen

Coderen zet een binair bestand om in platte tekst zodat het kanalen overleeft die alleen tekst dragen (bijvoorbeeld oudere e-mail of plakvakken). Decoderen keert dit om.

1. Selecteer een bestand en kies **Bestand ▸ Coderen…**, en kies vervolgens een formaat — MIME (Base64), UUE (uuencode) of XXE.
2. Om het origineel te herstellen, selecteer je het gecodeerde bestand en kies je **Bestand ▸ Decoderen…**. Het formaat wordt automatisch gedetecteerd.

## Bezette ruimte berekenen

Om te zien hoeveel ruimte een map of selectie werkelijk op schijf gebruikt, selecteer je de items en druk je op **Ctrl+L** (**Bestand ▸ Bezette ruimte berekenen…**). Peach Commander telt elk bestand erin op, inclusief submappen, en toont het totaal.

## Sneltoetsen

| Actie | Toets |
| --- | --- |
| Bezette ruimte berekenen | Ctrl+L |

## Opmerkingen

- Controlesommen, splitsen/samenvoegen en coderen/decoderen zijn gericht op geavanceerdere taken, maar elk is één venster met verstandige standaardwaarden.
- Wanneer een hulpmiddel nieuwe bestanden produceert (splitsdelen, een gecodeerd bestand, een controlesomlijst), worden deze geschreven naar de map die in het andere paneel wordt getoond — stel dat paneel eerst in op je bedoelde bestemming.
- Het verwijderen van duplicaten is definitief, afhankelijk van je verwijderinstellingen; bekijk elke groep zorgvuldig en houd ten minste één kopie van alles wat je nog nodig hebt.
