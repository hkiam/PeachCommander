---
title: Knappelinjen
slug: toolbar
section: Tilpasning
order: 110
related: [keyboard-shortcuts, settings]
---

Knappelinjen er stripen med ikonknapper langs toppen av vinduet. Hver knapp er en ettklikks snarvei du definerer selv: kjør en innebygd kommando, start et eksternt program eller en app, hopp til en mappe, eller åpne en hel underlinje med flere knapper. Det er den raskeste måten å sette handlingene du bruker mest innen rekkevidde, og du kan skreddersy den til akkurat måten du arbeider på.

## Tilpass knappelinjen

1. Velg **Konfigurasjon > Tilpass verktøylinje…**, eller høyreklikk linjen og velg **Rediger knappelinje…**.
2. Listen til venstre viser de gjeldende knappene. Bruk **+** for å legge til en knapp, **—** for å legge til en skillelinje, **−** for å fjerne den valgte knappen, og **↑ / ↓** for å endre rekkefølge.
3. Velg en knapp og fyll ut skjemaet til høyre:
   - **Kommando** – skriv en innebygd kommando, eller klikk **Velg…** for å velge en fra en liste. Du kan også skrive inn banen til et program eller en app, en mappe å åpne, eller en annen knappelinje å bruke som underlinje.
   - **Tekst** – etiketten og verktøytipset vist for knappen.
   - **Parametere** og **Startbane** – sendt til eksterne programmer. Plassholdere som `%P` (kildemappe), `%N` (gjeldende fil) og `%S` (valgte filer) fylles inn når knappen kjører.
   - **Ikon** – velg et SF Symbol eller bruk en fils eller apps eget ikon; slå på **kun ikon** for å skjule teksten.
4. Klikk **Lagre**. Stripen lastes inn på nytt med en gang.

![Knappelinjen langs toppen av vinduet med ikonknapper](screenshots/button-bar-crop.png)
*(Figur: Knappelinjen sitter over filpanelene; hver knapp kjører en kommando, et program, en mappe eller en underlinje.)*

## Underlinjer og overflyt

En knapp kan åpne en *underlinje* – et andre sett med knapper lagt over det første. Klikk den for å stige ned; en **◀**-knapp til venstre tar deg tilbake til den forrige linjen. Når det er flere knapper enn som får plass i vindusbredden, kollapser de ekstra bak en **»**-vinkel i høyre ende; klikk den for å nå dem.

## Slipp filer på en knapp

Du kan dra filer eller mapper rett på en knapp:

- **Mappeknapp** – de slupne elementene kopieres inn i den mappen i bakgrunnen.
- **Programknapp** – programmet kjører med de slupne elementene som utvalget sitt.
- **Kommandoknapp** – kommandoen kjører som vanlig.

## Vertikal knappelinje

For å flytte stripen fra toppen av vinduet til en kolonne ned langs venstre side, velg **Vis > Vertikal knappelinje**. Velg den igjen for å bytte tilbake til den horisontale stripen.

## Merknader

- Linjen lagres i en standard knappelinjefil som er kompatibel med Total Commander, så linjer du allerede har kan gjenbrukes.
- Ingen tastatursnarveier er tilordnet disse handlingene som standard, men du kan legge til dine egne – se [Tastatursnarveier](keyboard-shortcuts).
- En knapp uten ikon og uten kommando vises som en enkel skillelinje, praktisk for å gruppere beslektede knapper.
