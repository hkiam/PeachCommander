---
title: De logviewer
slug: log-viewer
section: Plug-ins
order: 128
related: [plugins, viewing-files, searching]
---

Zet de cursor op een logbestand en kies **Tonen als log…** om het te openen in een venster dat voor logs is gemaakt en niet voor tekst: één rij per regel, het niveau van elke regel herkend en gekleurd, een filter, en een tail die bijblijft terwijl het bestand nog wordt geschreven.

Het is een plug-in: u kunt hem uitschakelen of verwijderen via **Configuratie ▸ Plug-ins…**. Zonder hem toont F3 een log zoals elk ander tekstbestand.

![De logviewer met een servicelog, elk niveau in zijn eigen kleur](screenshots/log-viewer.png)
*(Afbeelding: elk niveau krijgt zijn eigen kleur en de weergave blijft het bestand volgen.)*

## Waarom het meteen opent

Het bestand wordt in het geheugen gekoppeld en er wordt alleen een index gebouwd van waar elke regel begint, op de achtergrond. Er wordt niets als tekst geladen voordat het op het scherm staat, en alleen de daadwerkelijk zichtbare regels worden gedecodeerd. Een log van meerdere gigabytes opent even snel als een klein, en naar het einde springen leest het midden niet.

## Niveaus en kleur

Elke regel wordt ingedeeld — **Fout**, **Waarschuwing**, **Info**, **Debug**, **Trace**, of **Onbekend** als het formaat niets prijsgeeft — en dienovereenkomstig gekleurd. De standaardkleuren volgen de lichte of donkere weergave; stel de uwe in bij de instellingen van de plug-in en die worden gebruikt.

In de kolom **Niveau** ziet u in één oogopslag waar de fouten zitten, en het filterveld beperkt de lijst tot wat u zoekt. Zet **Regex** aan om met een reguliere expressie te filteren in plaats van met platte tekst.

## Een bestand volgen dat nog groeit

Zet **Live (automatisch scrollen)** aan en het venster volgt het einde van het bestand terwijl er regels bij komen: de index wordt uitgebreid over de toegevoegde bytes in plaats van opnieuw gebouwd, dus dit blijft goedkoop hoe lang het bestand ook wordt. Scrol omhoog en u leest geschiedenis; de tail loopt eronder door.

## Uw weg vinden

| | |
| --- | --- |
| **Zoek…** | Doorzoekt de berichten; **Zoek (markeer en spring)…** markeert elke treffer zodat u ertussen kunt stappen |
| **Ga naar regel…** | Springt naar een fysiek regelnummer |
| **Ga naar datum/tijd…** | Springt naar de eerste regel vanaf een tijdstempel, bijv. `2024-01-15 10:23:45` |

Het kopiëren weet wat een logregel is: **Kopieer regel** neemt de regel onder de cursor, **Kopieer regelgroep (alle regels)** neemt de hele groep wanneer die over meerdere regels loopt — een stacktrace bijvoorbeeld — en **Kopieer geselecteerde regels** neemt precies wat u selecteerde.

## Structuren

**log4j**, **log4net** en **CSV** zijn ingebouwd, en de structuur wordt automatisch herkend; het venster toont waarvoor het gekozen heeft. Zijn uw logs geen van die, voeg dan uw eigen toe onder **Logstructuren** in de instellingen: een reguliere expressie met benoemde groepen voor de delen die ertoe doen.

```
(?<time>…)   (?<level>…)   (?<msg>…)
```

Een regel die de expressie niet herkent, verschijnt toch — hij wordt eenvoudig als Onbekend ingedeeld in plaats van weggelaten, want een log dat u niet kunt lezen is erger dan een log zonder kleuren.

## Weergave

**Toon regelnummers** en **Lange regels afbreken** staan in de instellingen. Het detailgebied onder de lijst toont altijd de volledige tekst van het geselecteerde item, afgebroken, wat de lijst ook doet.
