---
title: CSV-filer som tabell
slug: csv-lister
section: Plugins
order: 129
related: [plugins, viewing-files, log-viewer]
---

Tryck **F3** på en `.csv`- eller `.tsv`-fil så öppnas den som en riktig tabell — kolumner, rubriker, sortering och ett filter — i stället för som textrader med kommatecken i.

Det är ett tillägg: du kan stänga av det eller ta bort det under **Konfiguration ▸ Tillägg…**. Utan det visar F3 filen som ren text, vilket för en liten fil fortfarande är fullt läsbart.

## Avgränsaren räknas ut, den antas inte

Kommatecken, semikolon, tabb, lodstreck och kolon är alla kandidater. Tillägget räknar var och en över de första tjugo raderna och väljer den som förekommer lika många gånger på flest rader — en fil där varje rad har fyra semikolon är en semikolonfil, vad filändelsen än säger. Det spelar roll i praktiken: en `.csv` som exporterats av ett kalkylprogram på ett svenskt system är oftast semikolonseparerad, och en `.tsv` är inte alltid tabbseparerad.

Första raden behandlas som rubrikrad och blir kolumntitlarna.

## Sortera och filtrera

Klicka på en kolumnrubrik för att sortera på den, klicka igen för att vända. Sorteringen är **numerisk när båda värdena är tal** och alfabetisk annars, så en kolumn med storlekar sorterar 9 före 10 i stället för efter.

Sökfältet filtrerar medan du skriver, utan hänsyn till versaler. Som förval tittar det i alla kolumner; välj en kolumn i menyn bredvid för att bara titta där.

## Vad den inte gör

Tolken är medvetet liten, och en gräns är värd att känna till innan den överraskar dig: **en avgränsare inuti ett citerat fält behandlas fortfarande som avgränsare.** En rad som

```
"Smith, John",42
```

blir tre celler i stället för två. Omgivande citattecken tas bort när de omsluter ett helt fält, men i övrigt tolkas inte citering. För en fil där det spelar roll är den inbyggda visaren eller ett kalkylprogram det bättre verktyget.

Tomma rader hoppas över, och ett fält som sträcker sig över flera rader stöds inte.
