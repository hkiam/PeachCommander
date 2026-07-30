---
title: Bestanden selecteren
slug: selecting-files
section: Bestanden en mappen
order: 22
related: [copying-files, searching]
---

Voordat je iets kopieert, verplaatst, verwijdert of inpakt, vertel je Peach Commander eerst op welke items het moet werken. Het item waar je cursor op staat is altijd het huidige item, maar je kunt ook één of veel bestanden en mappen *markeren* zodat een opdracht op allemaal tegelijk wordt uitgevoerd. Gemarkeerde items vallen op met een aparte naamkleur in het paneel.

## Bestanden en mappen markeren

1. Klik op een rij om de cursor ernaartoe te verplaatsen. Eén klik selecteert alleen dat ene item.
2. Om meerdere items tegelijk te markeren, houd je Cmd ingedrukt en klik je op elk item, of houd je Shift ingedrukt en klik je om een bereik te markeren.
3. Om het item onder de cursor te markeren en in één beweging omlaag te stappen, druk je op Insert. Druk er herhaaldelijk op om snel een reeks opeenvolgende items te markeren. De Spatiebalk wisselt ook de markering van het huidige item (en toont de grootte van een map).
4. Om alles in het paneel te markeren, kies je Markeren > Alles selecteren (Ctrl+Num+), of druk je op Cmd+A. Kies Markeren > Alles deselecteren (Ctrl+Num-) om alle markeringen te wissen.

## Selecteren of deselecteren op basis van een patroon

1. Kies Markeren > Groep selecteren… (Num+) om items toe te voegen waarvan de namen aan een patroon voldoen, of Markeren > Groep deselecteren… (Num-) om overeenkomende items uit de huidige markeringen te verwijderen.
2. Typ een jokertekenmasker. Gebruik `*` voor willekeurige tekens en `?` voor een enkel teken. Scheid meerdere maskers met een puntkomma en vermeld uitzonderingen na een verticale streep — bijvoorbeeld `*.jpg;*.png` markeert alle afbeeldingen, en `*.*|*.bak` markeert alles behalve back-upbestanden.

![Het venster Groep selecteren met een jokertekenmasker getypt in het patroonveld](screenshots/select-by-mask.png)
*(Afbeelding: Bestanden markeren op basis van een jokertekenmasker.)*

## Omkeren, dezelfde extensie en herstellen

- **Selectie omkeren** (Num*, menu Markeren) draait elke markering om: gemarkeerde items worden ongemarkeerd en omgekeerd — handig voor "alles behalve deze".
- **Alles met dezelfde extensie selecteren** (Alt+Num+, menu Markeren) markeert elk bestand met dezelfde extensie als het item onder de cursor, zodat één toetsaanslag bijvoorbeeld alle `.pdf`-bestanden pakt.
- **Selectie herstellen** (Num/, menu Markeren) brengt je vorige set markeringen terug — handig als een opdracht ze heeft gewist of je de verkeerde groep hebt gemarkeerd.

## Sneltoetsen

| Actie | Toets |
|---|---|
| Markering wisselen, omlaag bewegen | Insert |
| Markering wisselen (huidig item) | Space |
| Alles selecteren / Alles deselecteren | Ctrl+Num+ / Ctrl+Num- |
| Alles selecteren (alternatief) | Cmd+A |
| Groep selecteren op masker | Num+ |
| Groep deselecteren op masker | Num- |
| Selectie omkeren | Num* |
| Alles met dezelfde extensie selecteren | Alt+Num+ |
| Vorige selectie herstellen | Num/ |

## Opmerkingen

- Markeringen en de cursor zijn onafhankelijk: de cursor met de pijltoetsen verplaatsen verandert niet wat er gemarkeerd is.
- Het item voor de bovenliggende map (`..`) kan nooit worden gemarkeerd.
- Groep selecteren, Groep deselecteren en Selectie omkeren werken op de bestandsnaam, zodat je mappen kunt insluiten of weglaten afhankelijk van de opties van het venster.
- Nadat een kopieer-, verplaats- of verwijderbewerking is voltooid, worden items die succesvol zijn verwerkt automatisch ongemarkeerd, terwijl de items die zijn mislukt gemarkeerd blijven zodat je ze opnieuw kunt proberen.
