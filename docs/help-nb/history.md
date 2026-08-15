---
title: Global historikk
slug: history
section: Organisere visningen
order: 47
related: [favorites, navigating]
---

Den globale historikken er ett vindu som husker ditt eget arbeid: mapper du har vært i, filer du har åpnet, handlinger du har utført og kommandoer du har kjørt. Trykk Ctrl+Cmd+H hvor som helst, begynn å skrive, og du er tilbake i gårsdagens mappe på ett sekund — uten mus.

## Åpne historikken

1. Trykk Ctrl+Cmd+H, eller velg **Gå > Historikk…**. Det spiller ingen rolle hvilket panel som er aktivt.
2. Skriv et par bokstaver. Treffet behøver verken være nøyaktig eller sammenhengende: `proj rep` finner `~/Projects/annual-report.txt`.
3. Beveg deg gjennom resultatene med Opp- og Ned-tastene mens du skriver videre.
4. Retur handler på den markerte oppføringen, Esc lukker vinduet.

Oppføringene er rangert etter hvor nylig *og* hvor ofte du brukte dem, så stedene du jobber mest, står allerede øverst. Festede oppføringer går alltid først.

![The global history window listing recently visited folders and opened files](screenshots/history-palette.png)
*(Figur: Den globale historikken — søkefeltet har fokus, og listen er rangert etter hvor nylig og hvor ofte du brukte hver oppføring.)*

## Filtrer etter type

Knappene under søkefeltet begrenser listen til alle oppføringer, mapper, filer, handlinger eller favoritter. Option+1 til Option+5 bytter mellom dem fra tastaturet.

## Gjør noe med en oppføring

| Handling | Snarvei |
| --- | --- |
| Åpne den markerte oppføringen | Return |
| Vis den i panelet, med markøren på den | Option+Return |
| Åpne en av de ni mest relevante oppføringene | Cmd+1 … Cmd+9 |
| Bytt panelet oppføringer åpnes i | Tab |
| Fest eller løsne oppføringen | Cmd+P |
| Fjern oppføringen fra historikken | Cmd+Delete |
| Kopier banen til oppføringen | Option+Cmd+C |
| Vis oppføringen i Finder | Cmd+Shift+R |
| Lukk historikken | Esc |

Retur gjør det oppføringen fortjener: en mappe åpnes i målpanelet, en fil åpnes som den ville fra panelet, og en kommandolinje legges i kommandolinjen slik at du kan se over den og kjøre den. Målpanelet står nederst i vinduet, og Tab bytter det.

## Gjenta en handling

En kopiering eller flytting står under **Handlinger**, og Retur kjører den på nytt — de samme elementene til den samme mappen, gjennom den vanlige overføringskøen og spørsmålene den stiller om overskriving. Elementer som ikke finnes lenger, hoppes over, og er ingen igjen, får du beskjed.

Slettinger og navnebytter står i listen, men gjentas aldri: Retur viser i stedet hvor de skjedde. Å gjenta en sletting bør ikke ligge én tast unna i en liste man bare skummer.

## Holde den i tømme

Innstillinger ▸ Annet avgjør om det føres en historikk, hvor mange oppføringer den beholder, og etter hvor mange dager den glemmer dem. Festede oppføringer er unntatt, og 0 dager beholder alt; listen ligger i `history.ini` i konfigurasjonsmappen din og overlever omstarter.

## Merknader

- Å åpne noe fra historikken teller som bruk — derfor fortsetter det du vender tilbake til å stige.
- Mapper inne i et arkiv, på en server eller i en pluginenhet huskes ikke: en slik bane betyr ingenting uten monteringen som laget den, og panelets egen historikk beholder dem så lenge den er åpen.
- Dette er ikke panelets egen mappehistorikk på Alt+Ned, som bare lister hvor det ene panelet har vært, i rekkefølge.
