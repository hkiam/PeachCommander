---
title: Knaplinjen
slug: toolbar
section: Tilpasning
order: 110
related: [keyboard-shortcuts, settings]
---

Knaplinjen er stribien af ikonknapper langs toppen af vinduet. Hver knap er en ét-klik-genvej, du selv definerer: kør en indbygget kommando, start et eksternt program eller en app, spring til en mappe, eller åbn en hel underlinje med flere knapper. Det er den hurtigste måde at få de handlinger, du bruger mest, inden for rækkevidde, og du kan skræddersy den præcis til den måde, du arbejder på.

## Tilpas knaplinjen

1. Vælg **Konfiguration > Tilpas værktøjslinje…**, eller højreklik på linjen og vælg **Rediger knaplinje…**.
2. Listen til venstre viser de aktuelle knapper. Brug **+** for at tilføje en knap, **—** for at tilføje en adskiller, **−** for at fjerne den valgte knap, og **↑ / ↓** for at ændre rækkefølge.
3. Vælg en knap og udfyld formularen til højre:
   - **Kommando** — indtast en indbygget kommando, eller klik på **Vælg…** for at vælge en fra en liste. Du kan også indtaste stien til et program eller en app, en mappe at åbne, eller en anden knaplinje at bruge som underlinje.
   - **Tekst** — etiketten og værktøjstippet vist for knappen.
   - **Parametre** og **Startsti** — videregivet til eksterne programmer. Pladsholdere såsom `%P` (kildemappe), `%N` (aktuel fil) og `%S` (valgte filer) udfyldes, når knappen kører.
   - **Ikon** — vælg et SF Symbol eller brug en fils eller apps eget ikon; slå **kun ikon** til for at skjule teksten.
4. Klik på **Gem**. Stribien genindlæses med det samme.

![Knaplinjen langs toppen af vinduet med ikonknapper](screenshots/button-bar-crop.png)
*(Figur: knaplinjen sidder over filpanelerne; hver knap kører en kommando, et program, en mappe eller en underlinje.)*

## Underlinjer og overløb

En knap kan åbne en *underlinje* — et andet sæt knapper lagt over det første. Klik på den for at gå ned; en **◀**-knap til venstre fører dig tilbage til den forrige linje. Når der er flere knapper, end der er plads til i vinduesbredden, foldes de ekstra bag en **»**-vinkel i højre ende; klik på den for at nå dem.

## Tilføj et program ved at slippe det på linjen

Du behøver ikke at åbne redigeringen for at lægge et værktøj på linjen. Træk et program, en app eller et script fra et panel — eller fra Finder — til **ledig plads** på linjen. En streg viser, hvor det lander; når du slipper, oprettes knappen der.

- **Programmer, apps og scripts** bliver til en knap, der kører dem på dit aktuelle udvalg: den nye knaps parametre er `%S`, de markerede filnavne. Tøm feltet i redigeringen, hvis værktøjet ikke skal have argumenter.
- **Mapper** bliver til en knap, der hopper derhen — og som kopierer filer derind, når du senere slipper dem på den.
- Det, der ikke kan køres, afvises: et almindeligt dokument har ikke kørselsrettighed, og en knap til det ville blot fejle ved klik.

At slippe på en **eksisterende** knap bevarer dens betydning: knappen køres med de slupne filer. Kun ledig plads opretter en ny.

## Slip filer på en knap

Du kan trække filer eller mapper direkte på en knap:

- **Mappeknap** — de slupne emner kopieres ind i den mappe i baggrunden.
- **Programknap** — programmet kører med de slupne emner som sin markering.
- **Kommandoknap** — kommandoen kører som normalt.

## Skjul knaplinjen

Vælg **Vis > Knaplinje** for at skjule linjen, og igen for at hente den tilbage. Den samme kontakt findes på siden **Layout** i indstillingerne, og valget huskes.

## Lodret knaplinje

For at flytte stribien fra toppen af vinduet til en kolonne langs venstre side, vælg **Vis > Lodret knaplinje**. Vælg den igen for at skifte tilbage til den vandrette stribe.

## Bemærkninger

- Linjen gemmes i en standard knaplinjefil, der er kompatibel med Total Commander, så linjer, du allerede har, kan genbruges.
- Der er som standard ikke tildelt tastaturgenveje til disse handlinger, men du kan tilføje dine egne — se [Tastaturgenveje](keyboard-shortcuts).
- En knap uden ikon og uden kommando vises som en simpel adskiller, praktisk til at gruppere relaterede knapper.
