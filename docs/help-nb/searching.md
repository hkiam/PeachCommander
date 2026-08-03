---
title: Finne filer
slug: searching
section: Finne filer
order: 60
related: [selecting-files, quick-search-and-filter]
---

Når du trenger å spore opp filer hvor som helst på Macen din — etter navn, etter hva de inneholder, eller etter størrelse og dato — bruk Finn filer-vinduet. Det søker i én eller flere mapper (og undermappene deres), kan se inni tekstfiler og arkiver, og lar deg sende alt det finner rett inn i et panel slik at du kan handle på resultatene som om de var en vanlig mappe.

## Finn filer etter navn

1. I panelet som viser mappen du vil søke i, velg **Kommandoer > Finn filer…** (eller trykk Cmd+Shift+F).
2. På **Generelt**-fanen skriver du et navnemønster i **Søk etter**. Du kan bruke jokertegn som `*.pdf` eller `report_*.docx`. For å søke i flere mapper samtidig, list dem opp i startmappefeltet atskilt med et semikolon (`;`).
3. Klikk **Start**. Treff vises i resultatlisten nedenfor etter hvert som de blir funnet.
4. Dobbeltklikk på et resultat for å hoppe til den filen i det aktive panelet, eller merk et resultat og klikk **Vis** (F3) for å åpne det i den innebygde visningen.

![Finn filer-vinduet på Generelt-fanen, som viser navnemønsteret, mappen og resultatlisten](screenshots/find-files-general.png)
*(Figur: Generelt-fanen — søk etter navnemønster på tvers av én eller flere mapper.)*

## Søk etter innhold, størrelse og dato

1. For å søke inni filer, velg **Finn tekst** på Generelt-fanen og skriv teksten du vil lete etter. Alternativer lar deg gjøre den **Skiller mellom store og små bokstaver**, samsvare bare med et **Helt ord**, behandle teksten som et **Regulært uttrykk**, gjøre et **Heksadesimalt innholdssøk**, eller finne filer som **Ikke inneholder** teksten.
2. Bytt til **Avansert**-fanen for å snevre inn resultatene etter **Størrelse** (for eksempel `10K` til `5M`), etter **endret dato**-område, eller til filer som er endret de siste N dagene.
3. Slå på **Søk inni arkiver** for å se i zip-familiens arkiver (zip, jar, war og lignende).
4. For å begrense søket til det du allerede har valgt, slå på **Søk bare i merkede elementer** før du starter.
5. Noen programtillegg kan gjøre en fil til tekst som filen selv ikke inneholder — dekompilator-tillegget gjør en `.class` til Java-kildekode. Slå på **Søk i tekst fra programtillegg**, og slike filer søkes som den teksten i stedet for som sine egne byte, slik at en formulering fra kildekoden finnes i en kompilert klasse. Valget vises bare når et slikt tillegg er installert, og det er tregere: å lage teksten kan bety én dekompilator per fil.

![Finn filer-vinduet på Avansert-fanen, som viser størrelse- og datofiltre](screenshots/find-files-advanced.png)
*(Figur: Avansert-fanen — filtrer etter størrelse, dato og andre attributter.)*

Hvis du har programtillegg som legger til innholdsfelter (som bildedimensjoner), lar **Programtillegg**-fanen deg kreve at et felt samsvarer med en betingelse — for eksempel bare bilder bredere enn 1000 piksler.

![Finn filer-vinduet på Programtillegg-fanen, som viser en betingelse for et innholdsfelt](screenshots/find-files-plugins.png)
*(Figur: Programtillegg-fanen — samsvar på innholdsfelter levert av programtillegg.)*

## Raske søk med Spotlight

For lokale mapper som macOS allerede har indeksert, slå på **Bruk Spotlight** på Generelt-fanen for nesten øyeblikkelige resultater. Spotlight søker i indeksen i stedet for å skanne filer, så det ignorerer regulære uttrykk, dybdegrenser for undermapper og omfanget bare-merkede.

## Gjenbruk og overlever resultatene dine

- **Send til liste** plasserer hvert resultat i det aktive panelet som en midlertidig liste, slik at du kan kopiere, flytte eller slette hele settet på én gang.
- På **Last inn / Lagre**-fanen velger du **Lagre som mal…** for å lagre det gjeldende søket (mønstre og alternativer) og velge det igjen senere fra mal-listen.

## Snarveier

| Handling | Snarvei |
| --- | --- |
| Åpne Finn filer | Cmd+Shift+F eller Option+F7 |
| Start / stopp søket | Start-knappen i vinduet |
| Vis det merkede resultatet | F3 |

## Merknader

- Innholdssøk leser hele filer for lokale mapper; på andre plasseringer hoppes svært store filer over (omtrent 16 MB, eller 64 MB når du bruker et regulært uttrykk).
- Søk inni arkiver stiger ned opptil fire nivåer av nestede arkiver.
- **Inkluder mapper i resultatene** lister også opp mapper hvis navn samsvarer, ikke bare filer.
- Spotlight dekker bare indekserte lokale mapper; for nettverksplasseringer eller mønsterbasert samsvar, la det være av og la Finn filer skanne.
