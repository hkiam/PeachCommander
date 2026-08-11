---
title: CSV-bestanden als tabel
slug: csv-lister
section: Plugins
order: 129
related: [plugins, viewing-files, log-viewer]
---

Druk op **F3** op een `.csv`- of `.tsv`-bestand en het opent als een echte tabel — kolommen, koppen, sortering en een filter — in plaats van als tekstregels met komma’s erin.

Het is een plug-in: u kunt hem uitschakelen of verwijderen via **Configuratie ▸ Plug-ins…**. Zonder hem toont F3 het bestand als platte tekst, wat voor een klein bestand nog prima leesbaar is.

## Het scheidingsteken wordt afgeleid, niet aangenomen

Komma, puntkomma, tab, verticale streep en dubbele punt komen allemaal in aanmerking. De plug-in telt ze elk over de eerste twintig regels en kiest degene die op de meeste regels even vaak voorkomt — een bestand waarvan elke rij vier puntkomma’s heeft, is een puntkomma-bestand, wat de extensie ook zegt. Dat is in de praktijk van belang: een `.csv` die door een rekenblad op een Europees systeem is geëxporteerd, is meestal met puntkomma’s gescheiden, en een `.tsv` is niet altijd met tabs gescheiden.

De eerste regel geldt als kopregel en wordt de kolomtitels.

## Sorteren en filteren

Klik op een kolomkop om erop te sorteren, klik nogmaals om om te keren. Sorteren gebeurt **numeriek wanneer beide waarden getallen zijn** en anders alfabetisch, zodat een kolom met groottes 9 vóór 10 zet in plaats van erna.

Het zoekveld filtert terwijl u typt, zonder onderscheid tussen hoofd- en kleine letters. Standaard kijkt het in alle kolommen; kies een kolom in het menu ernaast om alleen daar te kijken.

## Wat het niet doet

De parser is bewust klein, en één beperking is het waard te kennen voordat ze u verrast: **een scheidingsteken binnen een veld tussen aanhalingstekens wordt nog steeds als scheidingsteken behandeld.** Een rij als

```
"Smith, John",42
```

wordt drie cellen in plaats van twee. Omringende aanhalingstekens worden verwijderd wanneer ze een heel veld omsluiten, maar verder wordt het gebruik van aanhalingstekens niet geïnterpreteerd. Voor een bestand waar dat uitmaakt is de ingebouwde viewer of een rekenblad het betere gereedschap.

Lege regels worden overgeslagen, en een veld dat over meerdere regels loopt wordt niet ondersteund.
