---
title: Visningstilstande og sortering
slug: view-modes-and-sorting
section: Organisér din visning
order: 42
related: [panels-and-tabs, quick-search-and-filter]
---

Hvert panel kan vise sin mappe i det layout, der passer til opgaven: en detaljeret liste med kolonner, en kompakt flerkolonneliste med navne, et ikongitter, et galleri med store miniaturer eller et mappetræ. Du kan også sortere listen efter navn, filtype, størrelse eller dato, vælge præcis hvilke kolonner der vises, og slå naturlig (numerisk) sortering til, så navne med tal stiller sig op, som du forventer. Visningstilstand, sorteringsrækkefølge og kolonner indstilles pr. panel, så de to sider kan se helt forskellige ud.

## Skift visningstilstand

1. Klik på det panel, du vil ændre, så det bliver aktivt.
2. Åbn Vis-menuen og vælg en tilstand: **Fuld (Detaljer)** for kolonnelisten, **Kort (Kolonner)** for en tæt flerkolonneliste med navne, **Ikoner** for et ikongitter, **Miniaturer (Galleri)** for store forhåndsvisninger eller **Træ** for et mappetræ.
3. For hurtigt at bladre gennem tilstandene uden at åbne menuen, tryk på Cmd+Shift+M. Hvert tryk går til den næste tilstand.

![Et panel der viser de forskellige visningstilstande: detaljer, kort, ikoner og galleri](screenshots/view-modes.png)
*(Figur: den samme mappe vist som en detaljeret liste, en kort kolonneliste, et ikongitter og et galleri med miniaturer.)*

## Sortér fillisten

1. I Detaljer-visningen skal du klikke på et kolonneoverskrift (Navn, Type, Størrelse eller Dato) for at sortere efter den. En lille pil i overskriften viser den aktuelle sorteringskolonne og retning.
2. Klik på det samme overskrift igen for at vende rækkefølgen.
3. Du kan også vælge Vis > Sortér efter og vælge Navn, Filtype, Størrelse, Dato eller Usorteret.

Mapper sorteres altid sammen øverst, foran filer, og `..`-posten, der fører dig et niveau op, fastgøres først. Sortering efter navn eller filtype er stigende (A til Å) som standard; sortering efter størrelse eller dato er nyeste eller største først som standard.

## Vælg hvilke kolonner der vises

1. Vælg Konfiguration > Kolonner….
2. Slå kolonner til eller fra og indstil deres rækkefølge. Tilgængelige kolonner inkluderer Navn, Type, Størrelse, Dato, Attr (attributter), Mærker og Kommentar.
3. Anvend ændringerne. Kolonner påvirker det aktive panels Detaljer-visning.

![Kolonnekonfigurationsvinduet med listen over tilgængelige kolonner](screenshots/columns-config.png)
*(Figur: vælg hvilke kolonner der vises i Detaljer-visningen, og indstil deres rækkefølge.)*

## Genveje

| Handling | Genvej |
|---|---|
| Bladr gennem visningstilstande | Cmd+Shift+M |
| Kort (kolonner)-visning | Ctrl+F1 |
| Fuld (detaljer)-visning | Ctrl+F2 |
| Miniature (galleri)-visning | Ctrl+Shift+F1 |
| Træ-visning | Ctrl+F8 |
| Sortér efter navn | Ctrl+F3 |
| Sortér efter filtype | Ctrl+F4 |
| Sortér efter størrelse | Ctrl+F5 |
| Sortér efter dato | Ctrl+F6 |

## Tips

- Naturlig (numerisk) sortering er slået til som standard, så `file2` kommer før `file10` i stedet for efter. Du kan slå den fra i Konfiguration > Indstillinger under visningsindstillingerne.
- Du kan gøre en kolonne bredere eller smallere i Detaljer-visningen ved at trække i skillelinjen mellem kolonneoverskrifterne.
- Visningstilstand, sorteringsrækkefølge og kolonnevalg huskes pr. panel, så du kan have den ene side som en detaljeret liste og den anden som et fotogalleri.
