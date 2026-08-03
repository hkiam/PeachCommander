---
title: Find filer
slug: searching
section: Find filer
order: 60
related: [selecting-files, quick-search-and-filter]
---

Når du har brug for at spore filer hvor som helst på din Mac — efter navn, efter hvad de indeholder, eller efter størrelse og dato — brug vinduet Find filer. Det søger i én eller flere mapper (og deres undermapper), kan kigge inde i tekstfiler og arkiver og lader dig sende alt, det finder, direkte ind i et panel, så du kan handle på resultaterne, som var de en almindelig mappe.

## Find filer efter navn

1. I panelet der viser den mappe, du vil søge i, vælg **Kommandoer > Find filer…** (eller tryk på Cmd+Shift+F).
2. På fanen **Generelt** skal du indtaste et navnemønster i **Søg efter**. Du kan bruge jokertegn såsom `*.pdf` eller `rapport_*.docx`. For at søge i flere mapper på én gang, angiv dem i startmappe-feltet adskilt af et semikolon (`;`).
3. Klik på **Start**. Match vises i resultatlisten nedenfor, efterhånden som de findes.
4. Dobbeltklik på et resultat for at springe til den fil i det aktive panel, eller vælg et resultat og klik på **Vis** (F3) for at åbne det i den indbyggede fremviser.

![Vinduet Find filer på fanen Generelt der viser navnemønster, mappe og resultatliste](screenshots/find-files-general.png)
*(Figur: fanen Generelt — søg efter navnemønster på tværs af én eller flere mapper.)*

## Søg efter indhold, størrelse og dato

1. For at søge inde i filer skal du vælge **Find tekst** på fanen Generelt og indtaste teksten, der skal søges efter. Indstillinger lader dig gøre den **forskel på store/små**, kun matche et **helt ord**, behandle teksten som et **regulært udtryk**, lave en **hex-indholdssøgning** eller finde filer, der **ikke indeholder** teksten.
2. Skift til fanen **Avanceret** for at indsnævre resultater efter **størrelse** (for eksempel `10K` til `5M`), efter **ændringsdato**-interval eller til filer ændret inden for de sidste N dage.
3. Slå **Søg inde i arkiver** til for at kigge i arkiver af zip-familien (zip, jar, war og lignende).
4. For at begrænse søgningen til det, du allerede har valgt, slå **Søg kun i valgte emner** til før start.
5. Nogle plugins kan gøre en fil til tekst, som filen selv ikke indeholder — dekompilator-pluginet gør en `.class` til Java-kildekode. Slå **Søg i tekst fra plugins** til, og de filer søges som den tekst i stedet for som deres egne bytes, så en formulering fra kildekoden findes i en oversat klasse. Indstillingen vises kun, når et sådant plugin er installeret, og den er langsommere: at fremstille teksten kan betyde én dekompilator pr. fil.

![Vinduet Find filer på fanen Avanceret der viser størrelses- og datofiltre](screenshots/find-files-advanced.png)
*(Figur: fanen Avanceret — filtrér efter størrelse, dato og andre attributter.)*

Hvis du har plugins, der tilføjer indholdsfelter (såsom billeddimensioner), lader fanen **Plugins** dig kræve, at et felt matcher en betingelse — for eksempel kun billeder bredere end 1000 pixel.

![Vinduet Find filer på fanen Plugins der viser en indholdsfeltbetingelse](screenshots/find-files-plugins.png)
*(Figur: fanen Plugins — match på indholdsfelter leveret af plugins.)*

## Hurtige søgninger med Spotlight

For lokale mapper, macOS allerede har indekseret, slå **Brug Spotlight** til på fanen Generelt for næsten øjeblikkelige resultater. Spotlight søger i indekset i stedet for at scanne filer, så det ignorerer regulære udtryk, grænser for undermappedybde og kun-valgte-omfanget.

## Genbrug og videregivelse af dine resultater

- **Send til listeboks** placerer hvert resultat i det aktive panel som en midlertidig liste, så du kan kopiere, flytte eller slette hele sættet på én gang.
- På fanen **Indlæs / Gem** skal du vælge **Gem som skabelon…** for at gemme den aktuelle søgning (mønstre og indstillinger) og vælge den igen senere fra skabelonlisten.

## Genveje

| Handling | Genvej |
| --- | --- |
| Åbn Find filer | Cmd+Shift+F eller Option+F7 |
| Start / stop søgningen | Start-knappen i vinduet |
| Vis det valgte resultat | F3 |

## Bemærkninger

- Indholdssøgning læser hele filer for lokale mapper; på andre placeringer springes meget store filer over (cirka 16 MB, eller 64 MB ved brug af et regulært udtryk).
- Søgning inde i arkiver går ned til fire niveauer af indlejrede arkiver.
- **Inkludér mapper i resultater** viser også mapper, hvis navne matcher, ikke kun filer.
- Spotlight dækker kun indekserede lokale mapper; for netværksplaceringer eller mønsterbaseret matching, lad det være slået fra og lad Find filer scanne.
