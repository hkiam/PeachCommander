---
title: Visningsmoduser og sortering
slug: view-modes-and-sorting
section: Organisere visningen
order: 42
related: [panels-and-tabs, quick-search-and-filter]
---

Hvert panel kan vise mappen sin i den layouten som passer oppgaven: en detaljert liste med kolonner, en kompakt flerkolonnesliste med navn, et ikonrutenett, et galleri med store miniatyrer, eller et mappetre. Du kan også sortere listen etter navn, filtype, størrelse eller dato, velge nøyaktig hvilke kolonner som vises, og slå på naturlig (numerisk) sortering slik at navn med tall stiller seg opp som du forventer. Visningsmodus, sorteringsrekkefølge og kolonner settes per panel, så de to sidene kan se helt forskjellige ut.

## Bytt visningsmodus

1. Klikk på panelet du vil endre slik at det blir aktivt.
2. Åpne Vis-menyen og velg en modus: **Full (Detaljer)** for kolonnelisten, **Kort (Kolonner)** for en tett flerkolonnesliste med navn, **Ikoner** for et ikonrutenett, **Miniatyrer (Galleri)** for store forhåndsvisninger, eller **Tre** for et mappetre.
3. For å bla raskt gjennom modusene uten å åpne menyen, trykk Cmd+Shift+M. Hvert trykk går til neste modus.

![Et panel som viser de ulike visningsmodusene: detaljer, kort, ikoner og galleri](screenshots/view-modes.png)
*(Figur: Den samme mappen vist som en detaljert liste, en kort kolonneliste, et ikonrutenett og et galleri med miniatyrer.)*

## Sorter fillisten

1. I Detaljer-visningen, klikk på en kolonneoverskrift (Navn, Type, Størrelse eller Dato) for å sortere etter den. En liten pil i overskriften viser den gjeldende sorteringskolonnen og retningen.
2. Klikk på den samme overskriften igjen for å snu rekkefølgen.
3. Du kan også velge Vis > Sorter etter og velge Navn, Filtype, Størrelse, Dato eller Usortert.

Mapper sorteres alltid sammen øverst, foran filer, og `..`-oppføringen som tar deg opp ett nivå blir festet først. Sortering etter navn eller filtype er stigende (A til Å) som standard; sortering etter størrelse eller dato er nyest eller størst først som standard.

## Velg hvilke kolonner som vises

1. Velg Konfigurasjon > Kolonner….
2. Slå kolonner på eller av og sett rekkefølgen deres. Tilgjengelige kolonner inkluderer Navn, Type, Størrelse, Dato, Attr (attributter), Etiketter og Kommentar.
3. Bruk endringene. Kolonner påvirker det aktive panelets Detaljer-visning.

![Kolonnekonfigurasjonsvinduet med listen over tilgjengelige kolonner](screenshots/columns-config.png)
*(Figur: Velg hvilke kolonner som vises i Detaljer-visningen og sett rekkefølgen deres.)*

## Snarveier

| Handling | Snarvei |
|---|---|
| Bla gjennom visningsmoduser | Cmd+Shift+M |
| Kort (kolonner)-visning | Ctrl+F1 |
| Full (detaljer)-visning | Ctrl+F2 |
| Miniatyrer (galleri)-visning | Ctrl+Shift+F1 |
| Tre-visning | Ctrl+F8 |
| Sorter etter navn | Ctrl+F3 |
| Sorter etter filtype | Ctrl+F4 |
| Sorter etter størrelse | Ctrl+F5 |
| Sorter etter dato | Ctrl+F6 |

## Tips

- Naturlig (numerisk) sortering er på som standard, så `file2` kommer før `file10` i stedet for etter. Du kan slå den av i Konfigurasjon > Alternativer under visningsinnstillingene.
- Du kan gjøre en kolonne bredere eller smalere i Detaljer-visningen ved å dra i skillelinjen mellom kolonneoverskriftene.
- Bruker du macOS' tastaturnavigasjon (Systeminnstillinger ▸ Tastatur), tilhører raden Ctrl+F1 til Ctrl+F8 systemet — menylinjen, Dock, verktøylinjen — og den når aldri Peach Commander. Sett tasteskjemaet til **macOS** i innstillingene, så ligger visningsmodusene på Cmd+1, Cmd+2 og Cmd+3 og sorteringen på Alt+Cmd+1 til Alt+Cmd+4.
- Visningsmodus, sorteringsrekkefølge og kolonnevalg huskes per panel, så du kan ha den ene siden som en detaljert liste og den andre som et fotogalleri.
